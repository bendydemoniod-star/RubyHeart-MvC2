
$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3\Original_MvC2"

Add-Type -AssemblyName System.Drawing

$a = [System.Drawing.Bitmap]::FromFile("$base\Indexed\103.png")
$b = [System.Drawing.Bitmap]::FromFile("$base\RGB\anim212.png")

try {
    $ancho = $a.Width
    $alto = $a.Height
    $fondo = $b.GetPixel(0,0).ToArgb()

    $puntos = @(
        [PSCustomObject]@{X=0; Y=0}
        [PSCustomObject]@{X=44; Y=33}
        [PSCustomObject]@{X=87; Y=65}
        [PSCustomObject]@{X=29; Y=22}
        [PSCustomObject]@{X=58; Y=44}
    )

    $encontradas = 0

    Write-Host "Buscando en todo el lienzo de anim212.png..." -ForegroundColor Cyan

    for ($y = 0; $y -le (480-$alto); $y++) {
        for ($x = 0; $x -le (640-$ancho); $x++) {

            $posible = $true

            foreach ($p in $puntos) {
                $ca = $a.GetPixel($p.X,$p.Y).ToArgb()
                $cb = $b.GetPixel($x+$p.X,$y+$p.Y).ToArgb()

                if ($ca -eq 0 -and $cb -eq $fondo) {
                    continue
                }

                if ($ca -ne $cb) {
                    $posible = $false
                    break
                }
            }

            if (!$posible) {
                continue
            }

            $coincide = $true

            for ($py = 0; $py -lt $alto -and $coincide; $py++) {
                for ($px = 0; $px -lt $ancho; $px++) {

                    $ca = $a.GetPixel($px,$py).ToArgb()
                    $cb = $b.GetPixel($x+$px,$y+$py).ToArgb()

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
                $encontradas++

                Write-Host "COINCIDENCIA EXACTA: X=$x Y=$y" -ForegroundColor Green
            }
        }
    }

    Write-Host ""
    Write-Host "Búsqueda terminada."
    Write-Host "Coincidencias: $encontradas"
}
finally {
    $a.Dispose()
    $b.Dispose()
}
