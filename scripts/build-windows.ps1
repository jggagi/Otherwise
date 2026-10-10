param([string]$GodotPath, [string]$TemplatePath, [string]$Version = '0.1.0')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Version -notmatch '^[0-9A-Za-z._-]+$') { throw 'Version must be a plain directory name.' }
if (-not $GodotPath) {
    $engineCommand = Get-Command Godot_v4.7.2-stable_win64_console.exe -ErrorAction SilentlyContinue
    if (-not $engineCommand) { $engineCommand = Get-Command godot -ErrorAction Stop }
    $GodotPath = $engineCommand.Source
}
$versionAppData = $env:APPDATA
$versionLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $repoRoot '.local\build\appdata'
    $env:LOCALAPPDATA = Join-Path $repoRoot '.local\build\localappdata'
    $versionOutput = & $GodotPath --version
    if ($LASTEXITCODE -ne 0) { throw 'Godot version check failed.' }
    $engineVersion = ($versionOutput | Select-Object -First 1).Trim()
} finally {
    $env:APPDATA = $versionAppData
    $env:LOCALAPPDATA = $versionLocalAppData
}
if (-not $TemplatePath) {
    $templateVersion = ($engineVersion.Split('.')[0..2] -join '.') + '.stable'
    $TemplatePath = Join-Path $env:APPDATA "Godot\export_templates\$templateVersion\windows_release_x86_64.exe"
}
if (-not (Test-Path -LiteralPath $TemplatePath)) { throw "Missing matching release template: $TemplatePath" }
$releaseDir = Join-Path $repoRoot "releases\otherwise\$Version"
if (Test-Path -LiteralPath $releaseDir) { throw "Release already exists; choose a new Version: $releaseDir" }
$templateDir = Join-Path $repoRoot '.local\templates'
$buildDir = Join-Path $repoRoot '.local\build'
New-Item -ItemType Directory -Force -Path $templateDir,$buildDir,$releaseDir | Out-Null
Copy-Item -LiteralPath $TemplatePath -Destination (Join-Path $templateDir 'windows_release_x86_64.exe')
$originalAppData = $env:APPDATA
$originalLocalAppData = $env:LOCALAPPDATA
$originalTemp = $env:TEMP
$originalTmp = $env:TMP
try {
    $env:APPDATA = Join-Path $buildDir 'appdata'
    $env:LOCALAPPDATA = Join-Path $buildDir 'localappdata'
    $env:TEMP = Join-Path $buildDir 'tmp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
    Push-Location $repoRoot
    try {
        & $GodotPath --headless --path $repoRoot --editor --import *> (Join-Path $buildDir 'import.log')
        if ($LASTEXITCODE -ne 0) { throw 'Import failed; see .local/build/import.log' }
        if (Select-String -LiteralPath (Join-Path $buildDir 'import.log') -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet) { throw 'Import reported errors; see .local/build/import.log' }
        & $GodotPath --headless --path $repoRoot --export-release 'Windows Desktop' (Join-Path $releaseDir 'Otherwise.exe') *> (Join-Path $buildDir 'export.log')
        if ($LASTEXITCODE -ne 0) { throw 'Export failed; see .local/build/export.log' }
        if (Select-String -LiteralPath (Join-Path $buildDir 'export.log') -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet) { throw 'Export reported errors; see .local/build/export.log' }
    } finally { Pop-Location }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:TEMP = $originalTemp
    $env:TMP = $originalTmp
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'assets\fonts\OFL.txt') -Destination (Join-Path $releaseDir 'FONT-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\GODOT_LICENSES.txt') -Destination (Join-Path $releaseDir 'GODOT-LICENSES.txt')
Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\RELEASE_NOTES.md') -Destination (Join-Path $releaseDir 'README.txt')
Copy-Item -LiteralPath (Join-Path $repoRoot 'docs\ASSET_LICENSES.md') -Destination (Join-Path $releaseDir 'ASSET-LICENSES.txt')
$fileHashes = Get-ChildItem -LiteralPath $releaseDir -File | Sort-Object Name | ForEach-Object {
    "{0}  {1}" -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower(),$_.Name
}
[IO.File]::WriteAllLines((Join-Path $releaseDir 'SHA256SUMS.txt'),$fileHashes,[Text.UTF8Encoding]::new($false))
$archivePath = Join-Path (Split-Path -Parent $releaseDir) "Otherwise-$Version-Windows-x64.zip"
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $archivePath -CompressionLevel Optimal
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$archivePath.sha256","$archiveHash  $(Split-Path -Leaf $archivePath)`n",[Text.UTF8Encoding]::new($false))
Write-Output "WINDOWS_BUILD_PASS version=$Version engine=$engineVersion archive=$archivePath sha256=$archiveHash"
