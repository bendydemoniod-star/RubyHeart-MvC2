
$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3\Original_MvC2"

$rgbNombre = "anim462.png"
$posX = 290
$posY = 410

Add-Type -AssemblyName System.Drawing

$a = [System.Drawing.Bitmap]::FromFile("$base\Indexed\103.png")
$b = [System.Drawing.Bitmap]::FromFile("$base\RGB\$rgbNombre")

try {
    $encontrado = $false
    $posicion = $null
    $fondo = $b.GetPixel(0,0).ToArgb()

    for ($dy = -25; $dy -le 25 -and !$encontrado; $dy++) {
        for ($dx = -25; $dx -le 25 -and !$encontrado; $dx++) {

$inicioX = $posX + $dx
$inicioY = $posY + $dy

            if ($inicioX -lt 0 -or $inicioY -lt 0 -or
                $inicioX + $a.Width -gt $b.Width -or
                $inicioY + $a.Height -gt $b.Height) {
                continue
            }

            $coincide = $true

            for ($y = 0; $y -lt $a.Height -and $coincide; $y++) {
                for ($x = 0; $x -lt $a.Width; $x++) {

                    $ca = $a.GetPixel($x,$y).ToArgb()
                    $cb = $b.GetPixel($inicioX + $x,$inicioY + $y).ToArgb()

                    if ($ca -eq 0 -and $cb -eq $fondo) {
                        continue
                    }

                    if ($ca -ne $cb) {
                        $coincide = $false
                        break
                    }
                }
            }

            if ($coincide) {
                $encontrado = $true
                $posicion = "X=$inicioX, Y=$inicioY"
            }
        }
    }

    if ($encontrado) {
        Write-Host "COINCIDENCIA EXACTA: $posicion" -ForegroundColor Green
    }
    else {
        Write-Host "No se encontro coincidencia exacta." -ForegroundColor Yellow
    }
}
finally {
    $a.Dispose()
    $b.Dispose()
}
