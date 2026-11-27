
Add-Type -AssemblyName System.Drawing

$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3\Original_MvC2"

$a = [System.Drawing.Bitmap]::FromFile("$base\Indexed\103.png")

try {
    $ancho = $a.Width
    $alto = $a.Height

    foreach ($nombre in @("anim212.png", "anim215.png")) {

        $b = [System.Drawing.Bitmap]::FromFile("$base\RGB\$nombre")

        try {
            Write-Host "`nAnalizando $nombre..." -ForegroundColor Cyan

            $mapa = @{}

            # Registrar dónde aparece cada color en la imagen RGB
            for ($y = 0; $y -lt $b.Height; $y++) {
                for ($x = 0; $x -lt $b.Width; $x++) {

                    $color = $b.GetPixel($x,$y).ToArgb()

                    if (!$mapa.ContainsKey($color)) {
                        $mapa[$color] = [System.Collections.Generic.List[object]]::new()
                    }

                    $mapa[$color].Add([PSCustomObject]@{
                        X = $x
                        Y = $y
                    })
                }
            }

            # Buscar colores visibles de 103.png que existan en RGB
            $anclas = @()

            for ($y = 0; $y -lt $alto; $y++) {
                for ($x = 0; $x -lt $ancho; $x++) {

                    $color = $a.GetPixel($x,$y)

                    if ($color.A -eq 0) {
                        continue
                    }

                    $clave = $color.ToArgb()

                    if ($mapa.ContainsKey($clave)) {
                        $anclas += [PSCustomObject]@{
                            X = $x
                            Y = $y
                            Color = $clave
                            Repeticiones = $mapa[$clave].Count
                        }
                    }
                }
            }

            $mejores = $anclas |
                Sort-Object Repeticiones |
                Select-Object -First 5

            Write-Host "Anclas disponibles: $($anclas.Count)"
            Write-Host "Anclas seleccionadas:"

            $mejores | Format-Table X,Y,Repeticiones

            $fondo = $b.GetPixel(0,0).ToArgb()
            $probadas = @{}
            $encontradas = 0

            foreach ($ancla in $mejores) {

                foreach ($pos in $mapa[$ancla.Color]) {

                    $origenX = $pos.X - $ancla.X
                    $origenY = $pos.Y - $ancla.Y

                    if ($origenX -lt 0 -or $origenY -lt 0) {
                        continue
                    }

                    if ($origenX + $ancho -gt $b.Width -or
                        $origenY + $alto -gt $b.Height) {
                        continue
                    }

                    $id = "$origenX,$origenY"

                    if ($probadas.ContainsKey($id)) {
                        continue
                    }

                    $probadas[$id] = $true
                    $coincide = $true

                    for ($py = 0; $py -lt $alto -and $coincide; $py++) {
                        for ($px = 0; $px -lt $ancho; $px++) {

                            $ca = $a.GetPixel($px,$py)

                            if ($ca.A -eq 0) {
                                continue
                            }

                            $cb = $b.GetPixel(
                                $origenX + $px,
                                $origenY + $py
                            )

                            if ($ca.ToArgb() -ne $cb.ToArgb()) {
                                $coincide = $false
                                break
                            }
                        }
                    }

                    if ($coincide) {
                        $encontradas++

                        Write-Host "COINCIDENCIA: X=$origenX Y=$origenY" -ForegroundColor Green
                    }
                }
            }

            Write-Host "Coincidencias exactas: $encontradas"
        }
        finally {
            $b.Dispose()
        }
    }
}
finally {
    $a.Dispose()
}
