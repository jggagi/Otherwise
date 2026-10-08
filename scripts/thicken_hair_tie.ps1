# 加厚发圈环带：对 PNG 内孔做受限膨胀（距离变换），仅填充内部透明区。
# 用法: powershell -File scripts\thicken_hair_tie.ps1 -InPath <png> -ThickenPx 55
param(
  [Parameter(Mandatory = $true)][string]$InPath,
  [int]$ThickenPx = 55
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile($InPath)
$w = $src.Width; $h = $src.Height
$rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
$bd = $src.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadWrite,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$len = $bd.Stride*$h
$bytes = New-Object byte[] $len
[Runtime.InteropServices.Marshal]::Copy($bd.Scan0,$bytes,0,$len)

# alpha mask: 1=opaque
$mask = New-Object 'int[]' ($w*$h)
for($y=0;$y -lt $h;$y++){ $row=$y*$bd.Stride; for($x=0;$x -lt $w;$x++){ if($bytes[$row+$x*4+3] -gt 30){ $mask[$y*$w+$x]=1 } } }

# outside flood (4-neigh) from border over transparent pixels
$outside = New-Object 'bool[]' ($w*$h)
$stack = New-Object System.Collections.Generic.Stack[int]
for($x=0;$x -lt $w;$x++){ foreach($y in @(0,($h-1))){ $i=$y*$w+$x; if($mask[$i] -eq 0 -and -not $outside[$i]){ $outside[$i]=$true; $stack.Push($i) } } }
for($y=0;$y -lt $h;$y++){ foreach($x in @(0,($w-1))){ $i=$y*$w+$x; if($mask[$i] -eq 0 -and -not $outside[$i]){ $outside[$i]=$true; $stack.Push($i) } } }
while($stack.Count -gt 0){
	$i = $stack.Pop(); $cx=$i % $w; $cy=[Math]::Floor($i/$w)
	foreach($d in @(@{x=-1;y=0},@{x=1;y=0},@{x=0;y=-1},@{x=0;y=1})){
		$nx=$cx+$d.x; $ny=$cy+$d.y
		if($nx -ge 0 -and $nx -lt $w -and $ny -ge 0 -and $ny -lt $h){
			$j=$ny*$w+$nx
			if($mask[$j] -eq 0 -and -not $outside[$j]){ $outside[$j]=$true; $stack.Push($j) }
		}
	}
}

# chamfer distance (3/4) over mask; interior transparent pixels within range -> fill
$dist = New-Object 'double[]' ($w*$h)
for($i=0;$i -lt $dist.Count;$i++){ if($mask[$i] -eq 0){ $dist[$i]=1e9 } }
for($y=0;$y -lt $h;$y++){
	for($x=0;$x -lt $w;$x++){
		$i=$y*$w+$x
		if($mask[$i] -eq 1){ continue }
		if($x -gt 0){ $v=$dist[$i-1]+3; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($y -gt 0){ $v=$dist[$i-$w]+3; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($x -gt 0 -and $y -gt 0){ $v=$dist[$i-$w-1]+4; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($x -lt $w-1 -and $y -gt 0){ $v=$dist[$i-$w+1]+4; if($v -lt $dist[$i]){$dist[$i]=$v} }
	}
}
for($y=$h-1;$y -ge 0;$y--){
	for($x=$w-1;$x -ge 0;$x--){
		$i=$y*$w+$x
		if($mask[$i] -eq 1){ continue }
		if($x -lt $w-1){ $v=$dist[$i+1]+3; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($y -lt $h-1){ $v=$dist[$i+$w]+3; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($x -lt $w-1 -and $y -lt $h-1){ $v=$dist[$i+$w+1]+4; if($v -lt $dist[$i]){$dist[$i]=$v} }
		if($x -gt 0 -and $y -lt $h-1){ $v=$dist[$i+$w-1]+4; if($v -lt $dist[$i]){$dist[$i]=$v} }
	}
}

$fillR=42;$fillG=32;$fillB=28
$n2=0
for($i=0;$i -lt $mask.Count;$i++){
	if($mask[$i] -eq 0 -and -not $outside[$i] -and ($dist[$i]/3.0) -le $ThickenPx){
		$off = [Math]::Floor($i/$w)*$bd.Stride + ($i % $w)*4
		$bytes[$off]=$fillB; $bytes[$off+1]=$fillG; $bytes[$off+2]=$fillR; $bytes[$off+3]=255
		$n2++
	}
}
[Runtime.InteropServices.Marshal]::Copy($bytes,0,$bd.Scan0,$len)
$src.UnlockBits($bd)
$tmp = $InPath + ".tmp.png"
$src.Save($tmp,[System.Drawing.Imaging.ImageFormat]::Png)
$src.Dispose()
Move-Item -Force $tmp $InPath
Write-Host "[thicken] filled $n2 interior pixels (radius $ThickenPx) -> $InPath"
