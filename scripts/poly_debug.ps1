# Debug overlay: draw candidate furniture mask polygons over a screenshot,
# with vertex dots and indices, for visual polygon refinement.
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\poly_debug.ps1
param(
  [string]$Shot = "d:\TraeLab\Projects\Otherwise\.verify\00_initial_room.png",
  [string]$Out = "d:\TraeLab\Projects\Otherwise\.verify\poly_debug.png"
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Polygons in game (display) coordinates.
$polys = [ordered]@{
  "bed"   = @{ color = [System.Drawing.Color]::FromArgb(90, 255, 80, 80);
    pts = @(@(52,315), @(104,322), @(108,338), @(250,376), @(294,398), @(288,470), @(274,494), @(150,478), @(66,455), @(48,430)) }
  "bench" = @{ color = [System.Drawing.Color]::FromArgb(90, 80, 255, 80);
    pts = @(@(290,440), @(384,452), @(386,512), @(302,520)) }
  "table" = @{ color = [System.Drawing.Color]::FromArgb(90, 80, 160, 255);
    pts = @(@(486,390), @(568,392), @(580,415), @(570,458), @(556,494), @(486,494), @(476,452)) }
  "sofa"  = @{ color = [System.Drawing.Color]::FromArgb(90, 255, 220, 80);
    pts = @(@(650,430), @(670,418), @(735,420), @(760,430), @(790,450), @(798,470), @(794,506), @(790,528), @(652,528), @(644,502), @(642,468)) }
  "desk"  = @{ color = [System.Drawing.Color]::FromArgb(90, 255, 80, 220);
    pts = @(@(842,402), @(994,388), @(1000,414), @(1002,468), @(952,480), @(840,458)) }
}

$src = [System.Drawing.Bitmap]::FromFile($Shot)
$bmp = New-Object System.Drawing.Bitmap($src.Width, $src.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0)
$font = New-Object System.Drawing.Font("Arial", 8)

foreach ($k in $polys.Keys) {
  $entry = $polys[$k]
  $coords = $entry.pts
  $pts = New-Object 'System.Drawing.Point[]' $coords.Count
  for ($i = 0; $i -lt $coords.Count; $i++) {
    $pts[$i] = New-Object System.Drawing.Point($coords[$i][0], $coords[$i][1])
  }
  $brush = [System.Drawing.SolidBrush]::new($entry.color)
  $g.FillPolygon($brush, $pts)
  $pen = [System.Drawing.Pen]::new($entry.color, 2)
  $g.DrawPolygon($pen, $pts)
  for ($i = 0; $i -lt $pts.Count; $i++) {
    $g.FillEllipse([System.Drawing.Brushes]::White, ($pts[$i].X - 3), ($pts[$i].Y - 3), 6, 6)
    $g.DrawString("$k$i", $font, [System.Drawing.Brushes]::White, ($pts[$i].X + 4), ($pts[$i].Y + 4))
  }
}
$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); $src.Dispose()
Write-Host "saved $Out"
