param([string]$GodotPath, [string]$ArchivePath, [string]$ValidationName = 'packagecheck-0.1.0')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($ValidationName -notmatch '^[0-9A-Za-z._-]+$') { throw 'ValidationName must be a plain directory name.' }
if (-not $GodotPath) { $GodotPath = (Get-Command Godot_v4.7.2-stable_win64_console.exe -ErrorAction Stop).Source }
if (-not $ArchivePath) { $ArchivePath = Join-Path $repoRoot 'releases\otherwise\Otherwise-0.1.0-Windows-x64.zip' }
$validationDir = Join-Path $repoRoot ".local\validation\$ValidationName"
if (Test-Path -LiteralPath $validationDir) { throw 'Validation directory already exists; choose a new ValidationName.' }
$packageDir = Join-Path $validationDir 'unpacked'
Expand-Archive -LiteralPath $ArchivePath -DestinationPath $packageDir
foreach ($line in Get-Content (Join-Path $packageDir 'SHA256SUMS.txt')) {
    $expected,$name = $line -split '  ',2
    if ($name -notmatch '^[A-Za-z0-9._-]+$') { throw 'Unexpected manifest file name.' }
    if ((Get-FileHash -LiteralPath (Join-Path $packageDir $name) -Algorithm SHA256).Hash.ToLower() -ne $expected) { throw "Hash mismatch: $name" }
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
function Invoke-PackageTest([string[]]$EngineArguments,[string]$LogName,[string]$SuccessPattern) {
    $testLog = Join-Path $validationDir $LogName
    & $GodotPath @EngineArguments *> $testLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $testLog -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) { throw "Package test failed: $testLog" }
    if (-not (Select-String -LiteralPath $testLog -Pattern $SuccessPattern -Quiet)) { throw "Missing completion evidence: $testLog" }
    Get-Content -LiteralPath $testLog -Tail 1
}
try {
    $env:APPDATA = Join-Path $validationDir 'appdata'
    $env:LOCALAPPDATA = Join-Path $validationDir 'localappdata'
    $bootOut = Join-Path $validationDir 'boot.log'
    $bootErr = Join-Path $validationDir 'boot-errors.log'
    $process = Start-Process -FilePath (Join-Path $packageDir 'Otherwise.exe') -WorkingDirectory $packageDir -ArgumentList @('--headless','--verbose','--','--verify-boot') -WindowStyle Hidden -RedirectStandardOutput $bootOut -RedirectStandardError $bootErr -PassThru -Wait
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $bootErr -Pattern '^(ERROR:|SCRIPT ERROR:)' -Quiet)) { throw 'Release executable boot failed.' }
    if (-not (Select-String -LiteralPath $bootOut -Pattern 'RELEASE_BOOT_PASS' -Quiet)) { throw 'Release boot completion missing.' }
    $commonArguments = @('--path',$packageDir,'--main-pack',(Join-Path $packageDir 'Otherwise.pck'))
    Invoke-PackageTest (@('--headless')+$commonArguments+@('--script',(Join-Path $PSScriptRoot 'tests\package_probe.gd'))) 'probe.log' 'PACKAGE_PROBE_PASS'
    Invoke-PackageTest (@('--headless')+$commonArguments+@('--script',(Join-Path $PSScriptRoot 'tests\story_test.gd'))) 'story.log' 'failures=0'
    Invoke-PackageTest ($commonArguments+@('--audio-driver','Dummy','--script',(Join-Path $PSScriptRoot 'tests\input_test.gd'))) 'input.log' 'failures=0'
    Write-Output "WINDOWS_PACKAGE_VERIFY_PASS directory=$packageDir"
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
