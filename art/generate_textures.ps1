# Generate tileable surface textures (real PNGs) using .NET System.Drawing.
# No installs needed on Windows. Output: art/textures/*.png (1024x1024).
#   Run:  powershell -ExecutionPolicy Bypass -File art\generate_textures.ps1

Add-Type -AssemblyName System.Drawing

$size = 1024
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$out  = Join-Path $root "textures"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Save-Bmp($bmp, $name) {
    $path = Join-Path $out $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "wrote $path"
}

# Tinted speckle for natural grain. base = [r,g,b], jitter = +/- range.
function Add-Speckle($g, $count, $seed, $base, $jitter, $alpha, $dot) {
    $rnd = New-Object System.Random($seed)
    for ($k = 0; $k -lt $count; $k++) {
        $x = $rnd.Next($size); $y = $rnd.Next($size)
        $j = $rnd.Next(-$jitter, $jitter)
        $c = [System.Drawing.Color]::FromArgb($alpha,
            [math]::Max(0,[math]::Min(255,$base[0]+$j)),
            [math]::Max(0,[math]::Min(255,$base[1]+$j)),
            [math]::Max(0,[math]::Min(255,$base[2]+$j)))
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($b, $x, $y, $dot, $dot)
        $b.Dispose()
    }
}

# ── Pitch grass: mowed stripes + fine grass grain ────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$stripe = [int]($size / 10)
for ($i = 0; $i -lt 10; $i++) {
    $c = if ($i % 2 -eq 0) { [System.Drawing.Color]::FromArgb(58,142,72) } else { [System.Drawing.Color]::FromArgb(46,120,58) }
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillRectangle($b, ($i * $stripe), 0, $stripe + 1, $size)
    $b.Dispose()
}
Add-Speckle $g 26000 11 @(70,150,80) 28 70 2     # light blades
Add-Speckle $g 18000 12 @(36,96,46)  22 70 2     # dark blades
Save-Bmp $bmp "pitch_grass.png"
$g.Dispose(); $bmp.Dispose()

# ── Stadium seats: rows of rounded seats with aisles ─────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::FromArgb(24,26,34))
$cell = [int]($size / 24)
$green = [System.Drawing.Color]::FromArgb(48,170,90)
$gold  = [System.Drawing.Color]::FromArgb(245,205,55)
for ($ry = 0; $ry -lt 24; $ry++) {
    $rowCol = if ($ry % 2 -eq 0) { $green } else { $gold }
    $br = New-Object System.Drawing.SolidBrush($rowCol)
    $hi = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 255,255,255))
    for ($cx = 0; $cx -lt 24; $cx++) {
        if ($cx % 6 -eq 5) { continue }   # vertical aisle every 6 seats
        $x = $cx * $cell; $y = $ry * $cell
        $g.FillRectangle($br, $x + 3, $y + 3, $cell - 6, $cell - 5)             # seat
        $g.FillRectangle($hi, $x + 3, $y + 3, $cell - 6, [int](($cell - 6) / 3)) # top highlight
    }
    $br.Dispose(); $hi.Dispose()
}
Save-Bmp $bmp "stand_seats.png"
$g.Dispose(); $bmp.Dispose()

# ── Brick: offset courses with mortar + top-edge relief ──────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(54,56,64))   # mortar
$rnd = New-Object System.Random(7)
$bh = [int]($size / 20); $bw = [int]($size / 10); $mortar = 4
$row = 0
for ($y = 0; $y -lt $size; $y += $bh) {
    $offset = if ($row % 2 -eq 1) { [int]($bw / 2) } else { 0 }
    for ($x0 = -$bw; $x0 -lt ($size + $bw); $x0 += $bw) {
        $s = $rnd.Next(-14, 14)
        $col = [System.Drawing.Color]::FromArgb([math]::Max(0,[math]::Min(255,156+$s)),[math]::Max(0,[math]::Min(255,74+$s)),[math]::Max(0,[math]::Min(255,58+$s)))
        $b = New-Object System.Drawing.SolidBrush($col)
        $g.FillRectangle($b, $x0 + $offset + $mortar, $y + $mortar, $bw - $mortar, $bh - $mortar)
        $b.Dispose()
        $hiPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90,255,255,255))
        $g.DrawLine($hiPen, $x0 + $offset + $mortar, $y + $mortar, $x0 + $offset + $bw - 1, $y + $mortar)
        $hiPen.Dispose()
    }
    $row++
}
Add-Speckle $g 9000 33 @(120,60,46) 16 50 2
Save-Bmp $bmp "brick.png"
$g.Dispose(); $bmp.Dispose()

# ── Metal panel: brushed gradient + panel seams + rivets ─────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
for ($y = 0; $y -lt $size; $y++) {
    $base = 78 + [int](22 * [math]::Sin($y / 40.0))
    $c = [System.Drawing.Color]::FromArgb([math]::Max(0,[math]::Min(255,$base)),[math]::Max(0,[math]::Min(255,$base+5)),[math]::Max(0,[math]::Min(255,$base+14)))
    $pen = New-Object System.Drawing.Pen($c); $g.DrawLine($pen, 0, $y, $size, $y); $pen.Dispose()
}
$seam = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(35,38,46), 3)
for ($x = 256; $x -lt $size; $x += 256) { $g.DrawLine($seam, $x, 0, $x, $size) }
$seam.Dispose()
$rivet = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140,145,158))
for ($cy = 40; $cy -lt $size; $cy += 128) { for ($cx = 40; $cx -lt $size; $cx += 256) { $g.FillEllipse($rivet, $cx-5, $cy-5, 11, 11) } }
$rivet.Dispose()
Add-Speckle $g 6000 44 @(90,95,108) 12 40 2
Save-Bmp $bmp "metal_panel.png"
$g.Dispose(); $bmp.Dispose()

# ── Asphalt: dark speckle + faint cracks ─────────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(58,60,66))
Add-Speckle $g 30000 55 @(58,60,66) 16 60 2
$rnd = New-Object System.Random(99)
$crack = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,30,32,38), 2)
for ($c = 0; $c -lt 12; $c++) {
    $x = $rnd.Next($size); $y = $rnd.Next($size)
    $g.DrawLine($crack, $x, $y, $x + $rnd.Next(-120,120), $y + $rnd.Next(-120,120))
}
$crack.Dispose()
Save-Bmp $bmp "asphalt.png"
$g.Dispose(); $bmp.Dispose()

Write-Output "Done. Textures in $out"
