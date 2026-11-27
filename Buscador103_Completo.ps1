
Add-Type -AssemblyName System.Drawing

$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3"
$rutaIndexed = "$base\Original_MvC2\Indexed\103.png"
$rutaRGB = "$base\Original_MvC2\RGB"
$rutaCSV = "$base\RGB_analisis.csv"
$rutaSalida = "$base\Resultados_103.csv"

# Obtener perfil del sprite Indexed
function Obtener-Perfil {
    param(
        [string]$Ruta,
        [bool]$EsIndexed
    )

    $img = [System.Drawing.Bitmap]::FromFile($Ruta)

    try {
        $filas = @()
        $globalMinX = $img.Width

        for ($y = 0; $y -lt $img.Height; $y++) {
            $minX = $img.Width
            $maxX = -1
            $cantidad = 0

            for ($x = 0; $x -lt $img.Width; $x++) {
                $c = $img.GetPixel($x, $y)

                if ($EsIndexed) {
                    $visible = ($c.A -ne 0)
                } else {
                    $visible = -not (
                        $c.R -eq 255 -and
                        $c.G -eq 0 -and
                        $c.B -eq 255
                    )
                }

                if ($visible) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    $cantidad++
                }
            }

            if ($cantidad -gt 0) {
                if ($minX -lt $globalMinX) {
                    $globalMinX = $minX
                }

                $filas += [PSCustomObject]@{
                    Min = $minX
                    Max = $maxX
                    Count = $cantidad
                }
            } else {
                $filas += $null
            }
        }

        # Normalizar coordenadas horizontales
        $normalizado = @()

        foreach ($fila in $filas) {
            if ($null -eq $fila) {
                $normalizado += $null
            } else {
                $normalizado += [PSCustomObject]@{
                    Min = $fila.Min - $globalMinX
                    Max = $fila.Max - $globalMinX
                    Count = $fila.Count
                }
            }
        }

        return ,$normalizado
    }
    finally {
        $img.Dispose()
    }
}

Write-Host "Preparando sprite objetivo..."

$objetivo = Obtener-Perfil $rutaIndexed $true
$altoObjetivo = $objetivo.Count

Write-Host "Leyendo RGB_analisis.csv..."

$datos = Import-Csv $rutaCSV

# Seleccionar candidatos con dimensiones aproximadas
$candidatos = $datos | Where-Object {
    [Math]::Abs([double]$_.Ancho - 88) -le 25 -and
    [Math]::Abs([double]$_.Alto - 66) -le 25
}

Write-Host "Candidatos encontrados: $($candidatos.Count)"

$resultados = @()
$contador = 0

foreach ($dato in $candidatos) {
    $numero = [int]$dato.Numero
    $nombre = "anim{0:D3}.png" -f $numero
    $ruta = Join-Path $rutaRGB $nombre

    if (-not (Test-Path $ruta)) {
        continue
    }

    $contador++
    Write-Host "[$contador/$($candidatos.Count)] Analizando $nombre"

    $perfil = Obtener-Perfil $ruta $false
    $mejorError = [double]::MaxValue
    $mejorY = -1
    $mejoresFilas = 0

    for ($inicioY = 0; $inicioY -le ($perfil.Count - $altoObjetivo); $inicioY++) {
        $errorTotal = 0
        $filasExactas = 0

        for ($i = 0; $i -lt $altoObjetivo; $i++) {
            $a = $objetivo[$i]
            $b = $perfil[$inicioY + $i]

            if ($null -eq $a -and $null -eq $b) {
                $filasExactas++
                continue
            }

            if ($null -eq $a -or $null -eq $b) {
                $errorTotal += 100
                continue
            }

            $difFila = [Math]::Abs($a.Min - $b.Min) +
                       [Math]::Abs($a.Max - $b.Max) +
                       [Math]::Abs($a.Count - $b.Count)

            $errorTotal += $difFila

            if ($difFila -eq 0) {
                $filasExactas++
            }
        }

        if ($errorTotal -lt $mejorError) {
            $mejorError = $errorTotal
            $mejorY = $inicioY
            $mejoresFilas = $filasExactas
        }
    }

    $resultados += [PSCustomObject]@{
        Archivo = $nombre
        InicioY = $mejorY
        FilasCoincidentes = $mejoresFilas
        ErrorTotal = $mejorError
    }
}

Write-Host "`nOrdenando resultados..."

$resultados |
    Sort-Object ErrorTotal |
    Export-Csv $rutaSalida -NoTypeInformation -Encoding UTF8

Write-Host "`n=== MEJORES 20 RESULTADOS ==="

$resultados |
    Sort-Object ErrorTotal |
    Select-Object -First 20 |
    Format-Table -AutoSize

Write-Host "`nArchivo guardado en: $rutaSalida"
