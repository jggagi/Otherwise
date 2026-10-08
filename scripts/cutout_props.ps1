# Chroma-key cutout for Antigravity-generated prop sprites (JPG -> transparent PNG).
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\cutout_props.ps1 -InPath <src.jpg> -OutPath <dst.png>
# Keying: a pixel is background when its green excess (G - max(R,B)) exceeds
# $GreenExcess, or its RGB distance to the corner-sampled bg color is below
# $CornerDist. Green spill on kept pixels is capped at $SpillCap.
# Output is auto-cropped to the opaque bounding box (+1px pad) and saved as PNG32.
param(
  [Parameter(Mandatory = $true)][string]$InPath,
  [Parameter(Mandatory = $true)][string]$OutPath,
  [int]$GreenExcess = 45,
  [int]$CornerDist = 62,
  [int]$SpillCap = 18,
  [int]$Pad = 1
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile($InPath)
$w = $src.Width
$h = $src.Height

# --- work on a 32bpp ARGB copy ---
$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g0 = [System.Drawing.Graphics]::FromImage($bmp)
$g0.DrawImage($src, 0, 0, $w, $h)
$g0.Dispose()
$src.Dispose()

# --- sample background color from the four 12x12 corners ---
$rs = 0.0; $gs = 0.0; $bs = 0.0; $n = 0
foreach ($p in @(@{x = 0; y = 0 }, @{x = $w - 12; y = 0 }, @{x = 0; y = $h - 12 }, @{x = $w - 12; y = $h - 12 })) {
  for ($i = 0; $i -lt 12; $i++) {
    for ($j = 0; $j -lt 12; $j++) {
      $c = $bmp.GetPixel([Math]::Min($p.x + $i, $w - 1), [Math]::Min($p.y + $j, $h - 1))
      $rs += $c.R; $gs += $c.G; $bs += $c.B; $n++
    }
  }
}
$bgR = [int]($rs / $n); $bgG = [int]($gs / $n); $bgB = [int]($bs / $n)
Write-Host "[cutout] bg sample RGB=($bgR,$bgG,$bgB)"

# --- key pixels (LockBits for speed) ---
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$len = $bd.Stride * $h
$bytes = New-Object byte[] $len
[System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)

$minX = $w; $minY = $h; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $h; $y++) {
  $row = $y * $bd.Stride
  for ($x = 0; $x -lt $w; $x++) {
    $i = $row + $x * 4
    $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]
    $mx = [Math]::Max($r, $b)
    $isBg = (($g - $mx) -gt $GreenExcess)
    if (-not $isBg) {
      $dr = $r - $bgR; $dg = $g - $bgG; $db = $b - $bgB
      if (($dr * $dr + $dg * $dg + $db * $db) -lt ($CornerDist * $CornerDist)) { $isBg = $true }
    }
    if ($isBg) {
      $bytes[$i + 3] = 0
    } else {
      # green-spill suppression on kept pixels
      if (($g - $mx) -gt $SpillCap) { $bytes[$i + 1] = $mx + $SpillCap }
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $len)
$bmp.UnlockBits($bd)

if ($maxX -lt 0) { throw "no opaque pixels found in $InPath" }

# --- crop to bbox + pad ---
$cx = [Math]::Max(0, $minX - $Pad)
$cy = [Math]::Max(0, $minY - $Pad)
$cw = [Math]::Min($w - $cx, $maxX - $minX + 1 + 2 * $Pad)
$ch = [Math]::Min($h - $cy, $maxY - $minY + 1 + 2 * $Pad)

$out = New-Object System.Drawing.Bitmap($cw, $ch, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g1 = [System.Drawing.Graphics]::FromImage($out)
$g1.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)), (New-Object System.Drawing.Rectangle($cx, $cy, $cw, $ch)), [System.Drawing.GraphicsUnit]::Pixel)
$g1.Dispose()
$bmp.Dispose()

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$out.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host ("[cutout] {0} -> {1}  content={2}x{3} (bbox {4},{5}..{6},{7})" -f $InPath, $OutPath, $cw, $ch, $minX, $minY, $maxX, $maxY)
$out.Dispose()
