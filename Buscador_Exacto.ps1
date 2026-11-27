
Add-Type -AssemblyName System.Drawing

# Motor de comparación exacta
$codigoCSharp = @'
using System;
using System.Collections.Generic;
using System.Drawing;

public class SpriteMatcher
{
    public static string[] FindMatches(string pathA, string pathB)
    {
        List<string> matches = new List<string>();

        using (Bitmap a = new Bitmap(pathA))
        using (Bitmap b = new Bitmap(pathB))
        {
            Dictionary<int, int> counts = new Dictionary<int, int>();

            int anchorX = -1;
            int anchorY = -1;
            int anchorColor = 0;
            int minCount = int.MaxValue;
            int visible = 0;

            // Buscar el color menos frecuente del Indexed
            for (int y = 0; y < a.Height; y++)
            {
                for (int x = 0; x < a.Width; x++)
                {
                    Color p = a.GetPixel(x, y);
                    if (p.A == 0) continue;

                    visible++;
                    int key = (p.R << 16) | (p.G << 8) | p.B;

                    if (!counts.ContainsKey(key))
                        counts[key] = 0;

                    counts[key]++;
                }
            }

            foreach (var item in counts)
            {
                if (item.Value < minCount)
                    minCount = item.Value;
            }

            // Elegir una posición de ese color poco frecuente
            for (int y = 0; y < a.Height && anchorX < 0; y++)
            {
                for (int x = 0; x < a.Width; x++)
                {
                    Color p = a.GetPixel(x, y);
                    if (p.A == 0) continue;

                    int key = (p.R << 16) | (p.G << 8) | p.B;

                    if (counts[key] == minCount)
                    {
                        anchorX = x;
                        anchorY = y;
                        anchorColor = key;
                        break;
                    }
                }
            }

            HashSet<string> tested = new HashSet<string>();

            // Buscar el ancla en el RGB
            for (int ry = 0; ry < b.Height; ry++)
            {
                for (int rx = 0; rx < b.Width; rx++)
                {
                    Color q = b.GetPixel(rx, ry);
                    int key = (q.R << 16) | (q.G << 8) | q.B;

                    if (key != anchorColor) continue;

                    int ox = rx - anchorX;
                    int oy = ry - anchorY;

                    if (ox < 0 || oy < 0 ||
                        ox + a.Width > b.Width ||
                        oy + a.Height > b.Height)
                        continue;

                    string position = ox + "," + oy;
                    if (!tested.Add(position)) continue;

                    bool exact = true;

                    // Comparar todos los píxeles visibles
                    for (int y = 0; y < a.Height && exact; y++)
                    {
                        for (int x = 0; x < a.Width; x++)
                        {
                            Color p = a.GetPixel(x, y);
                            if (p.A == 0) continue;

                            Color r = b.GetPixel(ox + x, oy + y);

                            if (p.R != r.R ||
                                p.G != r.G ||
                                p.B != r.B)
                            {
                                exact = false;
                                break;
                            }
                        }
                    }

                    if (exact)
                        matches.Add(ox + "," + oy + "," + visible);
                }
            }
        }

        return matches.ToArray();
    }
}
'@
Add-Type -TypeDefinition $codigoCSharp -ReferencedAssemblies System.Drawing -ErrorAction Stop
$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3"
$indexedDir = "$base\Original_MvC2\Indexed"
$rgbDir = "$base\Original_MvC2\RGB"
$csvPath = "$base\RGB_analisis.csv"
$output = "$base\Correspondencias_Exactas.csv"

$datosRGB = Import-Csv $csvPath
$archivos = Get-ChildItem $indexedDir -Filter "*.png"

$resultados = [System.Collections.Generic.List[object]]::new()

$total = $archivos.Count
$actual = 0

foreach ($archivo in $archivos) {
    $actual++

    $img = [System.Drawing.Bitmap]::FromFile($archivo.FullName)

    try {
        $ancho = $img.Width
        $alto = $img.Height
    }
    finally {
        $img.Dispose()
    }

    Write-Host "`n[$actual/$total] Buscando $($archivo.Name) ($ancho x $alto)"

    # Candidatos por dimensiones aproximadas
    $candidatos = $datosRGB | Where-Object {
        [Math]::Abs([double]$_.Ancho - $ancho) -le 25 -and
        [Math]::Abs([double]$_.Alto - $alto) -le 25
    }

    foreach ($dato in $candidatos) {
        $numero = [int]$dato.Numero
        $nombreRGB = "anim{0:D3}.png" -f $numero
        $rutaRGB = Join-Path $rgbDir $nombreRGB

        if (-not (Test-Path $rutaRGB)) {
            continue
        }

        $coincidencias = [SpriteMatcher]::FindMatches(
            $archivo.FullName,
            $rutaRGB
        )

        foreach ($coincidencia in $coincidencias) {
            $partes = $coincidencia.Split(",")

            $resultados.Add([PSCustomObject]@{
                Indexed = $archivo.Name
                RGB = $nombreRGB
                X = [int]$partes[0]
                Y = [int]$partes[1]
                Pixeles = [int]$partes[2]
                Estado = "Exacta"
            })

            Write-Host "  COINCIDENCIA: $nombreRGB en X=$($partes[0]), Y=$($partes[1])" -ForegroundColor Green
        }
    }
}

$resultados |
    Export-Csv $output -NoTypeInformation -Encoding UTF8

Write-Host "`n================================"
Write-Host "BÚSQUEDA TERMINADA"
Write-Host "Sprites Indexed: $total"
Write-Host "Correspondencias exactas: $($resultados.Count)"
Write-Host "Archivo: $output"
Write-Host "================================"
