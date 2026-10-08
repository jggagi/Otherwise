# Extract furniture occluder sprites from the apartment background art.
# Each polygon (game coords) masks the same region in the native 1376x768
# source; native pixels inside the polygon are kept, outside becomes
# transparent. Keeping native pixels lets Godot scale the occluder with
# the same texture filtering as the background, so alignment is exact.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\extract_occluders.ps1
# Output: assets/occluders/<name>.png
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ROOT = "d:\TraeLab\Projects\Otherwise"
$SRC_IMG = Join-Path $ROOT "assets\apartment_bg_v1.jpg"
$OUT_DIR = Join-Path $ROOT "assets\occluders"
$KX = 1376.0 / 1152.0   # native / display
$KY = 768.0 / 648.0

# Silhouette polygons in game (display) coordinates.
$pieces = [ordered]@{
  "occ_bed" = @(
    @(52,315), @(104,322), @(108,338), @(250,376), @(294,398),
    @(288,470), @(274,494), @(150,478), @(66,455), @(48,430)
  )
  "occ_bench" = @(
    @(290,440), @(384,452), @(386,512), @(302,520)
  )
  "occ_table" = @(
    @(486,390), @(568,392), @(580,415), @(570,458),
    @(556,494), @(486,494), @(476,452)
  )
  "occ_sofa" = @(
    @(650,430), @(670,418), @(735,420), @(760,430), @(790,450),
    @(798,470), @(794,506), @(790,528), @(652,528), @(644,502), @(642,468)
  )
  "occ_desk" = @(
    @(842,402), @(994,388), @(1000,414), @(1002,468),
    @(952,480), @(840,458)
  )
}

if (-not (Test-Path $OUT_DIR)) { New-Item -ItemType Directory -Path $OUT_DIR | Out-Null }

foreach ($name in $pieces.Keys) {
  $poly = $pieces[$name]
  $src = [System.Drawing.Bitmap]::FromFile($SRC_IMG)
  $w = $src.Width; $h = $src.Height

  # Mask at native resolution.
  $mask = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $mg = [System.Drawing.Graphics]::FromImage($mask)
  $mg.Clear([System.Drawing.Color]::Black)
  $pts = New-Object 'System.Drawing.PointF[]' $poly.Count
  for ($i = 0; $i -lt $poly.Count; $i++) {
    $pts[$i] = New-Object System.Drawing.PointF(($poly[$i][0] * $KX), ($poly[$i][1] * $KY))
  }
  $mg.FillPolygon([System.Drawing.SolidBrush]::new([System.Drawing.Color]::White), $pts)
  $mg.Dispose()

  # Apply mask to a 32bpp copy via LockBits.
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g0 = [System.Drawing.Graphics]::FromImage($bmp)
  $g0.DrawImage($src, 0, 0, $w, $h)
  $g0.Dispose()
  $src.Dispose()

  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $md = $mask.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $len = $bd.Stride * $h
  $bytes = New-Object byte[] $len
  $mbytes = New-Object byte[] ($md.Stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)
  [System.Runtime.InteropServices.Marshal]::Copy($md.Scan0, $mbytes, 0, $mbytes.Length)

  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $h; $y++) {
    $row = $y * $bd.Stride; $mrow = $y * $md.Stride
    for ($x = 0; $x -lt $w; $x++) {
      $i = $row + $x * 4
      if ($mbytes[$mrow + $x * 3] -lt 128) {
        $bytes[$i + 3] = 0
      } else {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $len)
  $bmp.UnlockBits($bd); $mask.UnlockBits($md)

  $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
  $out = New-Object System.Drawing.Bitmap($cw, $ch, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g1 = [System.Drawing.Graphics]::FromImage($out)
  $g1.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$cw,$ch)), (New-Object System.Drawing.Rectangle($minX,$minY,$cw,$ch)), [System.Drawing.GraphicsUnit]::Pixel)
  $g1.Dispose(); $bmp.Dispose(); $mask.Dispose()
  $out.Save((Join-Path $OUT_DIR "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $out.Dispose()

  Write-Host ("{0}: native bbox ({1},{2}) {3}x{4} | game x={5:N1} y={6:N1} w={7:N1} h={8:N1}" -f $name,$minX,$minY,$cw,$ch,($minX/$KX),($minY/$KY),($cw/$KX),($ch/$KY))
}
