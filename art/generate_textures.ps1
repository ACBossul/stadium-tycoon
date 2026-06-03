# Generate tileable surface textures (real PNGs) using .NET System.Drawing.
# No installs needed on Windows. Output: art/textures/*.png (512x512).
# Mirror of generate_textures.py for machines without Python.
#   Run:  powershell -ExecutionPolicy Bypass -File art\generate_textures.ps1

Add-Type -AssemblyName System.Drawing

$size = 512
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$out  = Join-Path $root "textures"
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Save-Bmp($bmp, $name) {
    $path = Join-Path $out $name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "wrote $path"
}

function Add-Grain($g, $count, $seed, $maxAlpha) {
    $rnd = New-Object System.Random($seed)
    for ($k = 0; $k -lt $count; $k++) {
        $x = $rnd.Next($size); $y = $rnd.Next($size)
        $a = $rnd.Next(8, $maxAlpha)
        $v = if ($rnd.Next(2) -eq 0) { 0 } else { 255 }
        $c = [System.Drawing.Color]::FromArgb($a, $v, $v, $v)
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($b, $x, $y, 1, 1)
        $b.Dispose()
    }
}

# ── Pitch grass: mowed stripes ───────────────────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$stripe = [int]($size / 8)
for ($i = 0; $i -lt 8; $i++) {
    $c = if ($i % 2 -eq 0) { [System.Drawing.Color]::FromArgb(52,132,64) } else { [System.Drawing.Color]::FromArgb(40,110,54) }
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillRectangle($b, ($i * $stripe), 0, $stripe, $size)
    $b.Dispose()
}
Add-Grain $g 5000 11 26
Save-Bmp $bmp "pitch_grass.png"
$g.Dispose(); $bmp.Dispose()

# ── Stadium seats: checkered team colors ─────────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(28,30,40))
$cell = [int]($size / 16)
$green = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,165,85))
$gold  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245,210,60))
for ($cy = 0; $cy -lt $size; $cy += $cell) {
    for ($cx = 0; $cx -lt $size; $cx += $cell) {
        $brush = if ((($cx / $cell) + ($cy / $cell)) % 2 -eq 0) { $green } else { $gold }
        $g.FillRectangle($brush, $cx + 2, $cy + 2, $cell - 4, $cell - 4)
    }
}
$green.Dispose(); $gold.Dispose()
Add-Grain $g 2500 22 20
Save-Bmp $bmp "stand_seats.png"
$g.Dispose(); $bmp.Dispose()

# ── Brick: offset courses ────────────────────────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(60,62,70))  # mortar
$rnd = New-Object System.Random(7)
$bh = [int]($size / 16); $bw = [int]($size / 8); $mortar = 3
$row = 0
for ($y = 0; $y -lt $size; $y += $bh) {
    $offset = if ($row % 2 -eq 1) { [int]($bw / 2) } else { 0 }
    for ($x0 = -$bw; $x0 -lt ($size + $bw); $x0 += $bw) {
        $s = $rnd.Next(-12, 12)
        $c = [System.Drawing.Color]::FromArgb([math]::Max(0,[math]::Min(255,150+$s)), [math]::Max(0,[math]::Min(255,70+$s)), [math]::Max(0,[math]::Min(255,55+$s)))
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillRectangle($b, $x0 + $offset + $mortar, $y + $mortar, $bw - $mortar, $bh - $mortar)
        $b.Dispose()
    }
    $row++
}
Add-Grain $g 3000 33 18
Save-Bmp $bmp "brick.png"
$g.Dispose(); $bmp.Dispose()

# ── Metal panel: horizontal bands + rivets ───────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
for ($y = 0; $y -lt $size; $y++) {
    $base = 70 + [int](25 * [math]::Sin($y / 26.0))
    $c = [System.Drawing.Color]::FromArgb([math]::Max(0,[math]::Min(255,$base)), [math]::Max(0,[math]::Min(255,$base+4)), [math]::Max(0,[math]::Min(255,$base+12)))
    $pen = New-Object System.Drawing.Pen($c)
    $g.DrawLine($pen, 0, $y, $size, $y)
    $pen.Dispose()
}
$rivet = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(130,135,145))
for ($cy = 32; $cy -lt $size; $cy += 96) {
    for ($cx = 32; $cx -lt $size; $cx += 96) {
        $g.FillEllipse($rivet, $cx - 3, $cy - 3, 7, 7)
    }
}
$rivet.Dispose()
Add-Grain $g 2000 44 16
Save-Bmp $bmp "metal_panel.png"
$g.Dispose(); $bmp.Dispose()

# ── Asphalt: dark speckle ────────────────────────────────────────────────────
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(60,62,68))
Add-Grain $g 9000 55 30
Save-Bmp $bmp "asphalt.png"
$g.Dispose(); $bmp.Dispose()

Write-Output "Done. Upload the PNGs in $out to Roblox and send back the asset IDs."
