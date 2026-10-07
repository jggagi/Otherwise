# Slice a walk "strip" image (two mirrored step poses side by side, split by
# a thin #FF0000 vertical line) into two transparent PNG frames.
# Green key is applied per half, then both halves are cropped to the UNION
# bounding box, so the output frames share identical canvas size and the
# same feet baseline / horizontal anchor - swapping frames cannot jitter.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\slice_walk_strip.ps1 `
#     -InPath <strip.jpg> -OutA <a.png> -OutB <b.png>
param(
  [Parameter(Mandatory = $true)][string]$InPath,
  [Parameter(Mandatory = $true)][string]$OutA,
  [Parameter(Mandatory = $true)][string]$OutB,
  [int]$GreenExcess = 45,
  [int]$CornerDist = 62,
  [int]$SpillCap = 18,
  [int]$Pad = 2
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src0 = [System.Drawing.Bitmap]::FromFile($InPath)
$W = $src0.Width; $H = $src0.Height

# --- detect red divider column ---
$bestX = -1; $bestCount = -1
for ($x = 0; $x -lt $W; $x++) {
  $cnt = 0
  for ($y = 0; $y -lt $H; $y += 4) {
    $c = $src0.GetPixel($x, $y)
    if (($c.R - $c.G) -gt 55 -and $c.B -lt 80) { $cnt++ }
  }
  if ($cnt -gt $bestCount) { $bestCount = $cnt; $bestX = $x }
}
if ($bestX -lt 0 -or $bestCount -lt ($H / 8)) { throw "red divider not found in $InPath" }
Write-Host "[slice] divider at x=$bestX"

# --- key one half; returns R,G,B byte arrays + mask, in half-local coords ---
function Process-Half($src, $x0, $x1) {
  $w = $x1 - $x0; $h = $src.Height; $n = $w * $h

  # corner background sample (10x10 at the four corners of the half)
  $rs = 0.0; $gs = 0.0; $bs = 0.0; $k = 0
  foreach ($p in @(@(0,0), @(($w-10),0), @(0,($h-10)), @(($w-10),($h-10)))) {
    for ($i = 0; $i -lt 10; $i++) {
      for ($j = 0; $j -lt 10; $j++) {
        $c = $src.GetPixel($x0 + [Math]::Min($p[0]+$i, ($w-1)), [Math]::Min($p[1]+$j, ($h-1)))
        $rs += $c.R; $gs += $c.G; $bs += $c.B; $k++
      }
    }
  }
  $bgR = [int]($rs/$k); $bgG = [int]($gs/$k); $bgB = [int]($bs/$k)

  # 32bpp copy of the half
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g0 = [System.Drawing.Graphics]::FromImage($bmp)
  $g0.DrawImage($src, (New-Object System.Drawing.Rectangle(0,0,$w,$h)), (New-Object System.Drawing.Rectangle($x0,0,$w,$h)), [System.Drawing.GraphicsUnit]::Pixel)
  $g0.Dispose()

  $rect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
  $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $len = $bd.Stride * $h
  $bytes = New-Object byte[] $len
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)

  $mask = New-Object byte[] $n
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $bd.Stride
    for ($x = 0; $x -lt $w; $x++) {
      $i = $row + $x*4
      $b = $bytes[$i]; $g = $bytes[$i+1]; $r = $bytes[$i+2]
      $mx = [Math]::Max($r,$b)
      $isBg = (($g - $mx) -gt $GreenExcess)
      if (-not $isBg) {
        $dr = $r-$bgR; $dg = $g-$bgG; $db = $b-$bgB
        if (($dr*$dr + $dg*$dg + $db*$db) -lt ($CornerDist*$CornerDist)) { $isBg = $true }
      }
      if ($isBg) {
        $bytes[$i+3] = 0
      } else {
        if (($g - $mx) -gt $SpillCap) { $bytes[$i+1] = $mx + $SpillCap }
        $mask[$y*$w+$x] = 1
      }
    }
  }
  # clear a 6px border band: removes JPEG edge speckle and divider sliver
  $band = 6
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $band; $x++) { $mask[($y*$w+$x)] = 0; $bytes[($bd.Stride*$y+$x*4+3)] = 0 }
    for ($x = ($w-$band); $x -lt $w; $x++) { $mask[($y*$w+$x)] = 0; $bytes[($bd.Stride*$y+$x*4+3)] = 0 }
  }
  for ($y = 0; $y -lt $band; $y++) {
    for ($x = 0; $x -lt $w; $x++) { $mask[($y*$w+$x)] = 0; $bytes[($bd.Stride*$y+$x*4+3)] = 0 }
  }
  for ($y = ($h-$band); $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) { $mask[($y*$w+$x)] = 0; $bytes[($bd.Stride*$y+$x*4+3)] = 0 }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $len)
  $bmp.UnlockBits($bd)

  return @{ bmp = $bmp; mask = $mask; w = $w; h = $h; bg = @($bgR,$bgG,$bgB) }
}

$halfA = Process-Half $src0 0 $bestX
$halfB = Process-Half $src0 ($bestX + 1) $W
$src0.Dispose()

# --- align the two loop frames by silhouette overlap (IoU) ---
# Loop frames must swap in place, but the generator does not center poses
# identically. Find the B-to-A offset maximizing mask overlap: coarse grid
# search, then full-resolution pixel refinement.
$KEY = 4096  # hash-key stride, larger than any source width

function Get-MaskKeys($half) {
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  $list = New-Object 'System.Collections.Generic.List[int]'
  for ($p = 0; $p -lt ($half.w * $half.h); $p++) {
    if ($half.mask[$p] -ne 1) { continue }
    $x = $p % $half.w; $y = [int]($p / $half.w)
    $k = $y * $KEY + $x
    [void]$set.Add($k); [void]$list.Add($k)
  }
  return @{ set = $set; list = $list }
}
$mkA = Get-MaskKeys $halfA
$mkB = Get-MaskKeys $halfB
if ($mkA.list.Count -eq 0 -or $mkB.list.Count -eq 0) { throw 'empty pose in a half' }

$COARSE_W = 120; $COARSE_H = 170
function Get-Coarse($half) {
  $sil = New-Object System.Drawing.Bitmap($half.w, $half.h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $rect = New-Object System.Drawing.Rectangle(0, 0, $half.w, $half.h)
  $bd = $sil.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $b = New-Object byte[] ($bd.Stride * $half.h)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $b, 0, $b.Length)
  for ($p = 0; $p -lt ($half.w * $half.h); $p++) {
    if ($half.mask[$p] -ne 1) { continue }
    $x = $p % $half.w; $y = [int]($p / $half.w)
    $i = $bd.Stride * $y + $x * 4
    $b[$i] = 255; $b[$i+1] = 255; $b[$i+2] = 255; $b[$i+3] = 255
  }
  [System.Runtime.InteropServices.Marshal]::Copy($b, 0, $bd.Scan0, $b.Length)
  $sil.UnlockBits($bd)
  $small = New-Object System.Drawing.Bitmap($COARSE_W, $COARSE_H)
  $g0 = [System.Drawing.Graphics]::FromImage($small)
  $g0.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g0.Clear([System.Drawing.Color]::Black)
  $g0.DrawImage($sil, (New-Object System.Drawing.Rectangle(0, 0, $COARSE_W, $COARSE_H)), (New-Object System.Drawing.Rectangle(0, 0, $half.w, $half.h)), [System.Drawing.GraphicsUnit]::Pixel)
  $g0.Dispose(); $sil.Dispose()
  $set = New-Object 'System.Collections.Generic.HashSet[int]'
  for ($y = 0; $y -lt $COARSE_H; $y++) {
    for ($x = 0; $x -lt $COARSE_W; $x++) {
      if ($small.GetPixel($x, $y).R -ge 128) { [void]$set.Add(($y * $COARSE_W + $x)) }
    }
  }
  $small.Dispose()
  return $set
}
$cA = Get-Coarse $halfA
$cB = Get-Coarse $halfB

# coarse IoU search
$nA = $cA.Count
$rangeX = [int]($COARSE_W / 3); $rangeY = [int]($COARSE_H / 5)
$bestDX = 0; $bestDY = 0; $bestScore = -1.0
for ($dy = -$rangeY; $dy -le $rangeY; $dy++) {
  for ($dx = -$rangeX; $dx -le $rangeX; $dx++) {
    $inter = 0
    foreach ($k in $cB) {
      $x = $k % $COARSE_W; $y = [int]($k / $COARSE_W)
      $nx = $x + $dx; $ny = $y + $dy
      if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $COARSE_W -or $ny -ge $COARSE_H) { continue }
      if ($cA.Contains(($ny * $COARSE_W + $nx))) { $inter++ }
    }
    $union = $nA + $cB.Count - $inter
    $score = $inter / $union
    if ($score -gt $bestScore) { $bestScore = $score; $bestDX = $dx; $bestDY = $dy }
  }
}

# seed in full pixels, then refine +/-7px on full-resolution masks
$seedX = [int]($bestDX * ($halfA.w / $COARSE_W))
$seedY = [int]($bestDY * ($halfA.h / $COARSE_H))
$fullCountA = $mkA.set.Count; $fullCountB = $mkB.set.Count
$bestFX = $seedX; $bestFY = $seedY; $bestFull = -1.0
for ($dy = -7; $dy -le 7; $dy++) {
  for ($dx = -7; $dx -le 7; $dx++) {
    $ox = $seedX + $dx; $oy = $seedY + $dy
    $inter = 0
    foreach ($k in $mkB.list) {
      $x = $k % $KEY; $y = [int]($k / $KEY)
      if ($mkA.set.Contains((($y + $oy) * $KEY + ($x + $ox)))) { $inter++ }
    }
    $score = $inter / ($fullCountA + $fullCountB - $inter)
    if ($score -gt $bestFull) { $bestFull = $score; $bestFX = $ox; $bestFY = $oy }
  }
}
Write-Host ("[slice] align offset=({0},{1}) IoU={2:0.000}" -f $bestFX, $bestFY, $bestFull)

# --- compose both frames into one shared canvas at the aligned offset ---
$minAX = 100000; $minAY = 100000; $maxAX = -1; $maxAY = -1
foreach ($k in $mkA.list) {
  $x = $k % $KEY; $y = [int]($k / $KEY)
  if ($x -lt $minAX) { $minAX = $x }; if ($x -gt $maxAX) { $maxAX = $x }
  if ($y -lt $minAY) { $minAY = $y }; if ($y -gt $maxAY) { $maxAY = $y }
}
$minBX = $minAX; $minBY = $minAY; $maxBX = $maxAX; $maxBY = $maxAY
foreach ($k in $mkB.list) {
  $x = ($k % $KEY) + $bestFX; $y = ([int]($k / $KEY)) + $bestFY
  if ($x -lt $minBX) { $minBX = $x }; if ($x -gt $maxBX) { $maxBX = $x }
  if ($y -lt $minBY) { $minBY = $y }; if ($y -gt $maxBY) { $maxBY = $y }
}
$cw0 = ($maxBX - $minBX + 1) + 2 * $Pad
$ch0 = ($maxBY - $minBY + 1) + 2 * $Pad

function Save-Aligned($half, $offX, $offY, $path) {
  $out = New-Object System.Drawing.Bitmap($cw0, $ch0, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g0 = [System.Drawing.Graphics]::FromImage($out)
  $g0.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g0.DrawImage($half.bmp, ($Pad - $minBX + $offX), ($Pad - $minBY + $offY))
  $g0.Dispose()
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $out.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()
}

Save-Aligned $halfA 0 0 $OutA
Save-Aligned $halfB $bestFX $bestFY $OutB
Write-Host ("[slice] frames {0}x{1}: {2} , {3}" -f $cw0, $ch0, $OutA, $OutB)
$halfA.bmp.Dispose(); $halfB.bmp.Dispose()
