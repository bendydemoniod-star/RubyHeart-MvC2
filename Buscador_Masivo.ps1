
Add-Type -AssemblyName System.Drawing -ErrorAction Stop

$codigo = @'
using System;
using System.Collections.Generic;
using System.Drawing;

public class BatchMaskMatcherV2
{
    public class Anchor
    {
        public int X, Y, Pattern, Frequency;
    }

    public class Target
    {
        public string Name;
        public int W, H, Total;
        public byte[] Mask;
        public List<Anchor> Anchors;
    }

    public class RgbIndex
    {
        public int W, H;
        public byte[] Mask;
        public List<int>[] Positions;
    }

    public class Match
    {
        public int X, Y, Intersection;
        public double Coverage, Precision, IoU;
    }

    static byte[] LoadMask(string path, bool indexed,
                           out int w, out int h)
    {
        using (Bitmap bmp = new Bitmap(path))
        {
            w = bmp.Width;
            h = bmp.Height;
            byte[] mask = new byte[w * h];

            for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                Color c = bmp.GetPixel(x, y);
                bool visible = indexed
                    ? c.A != 0
                    : !(c.R == 255 && c.G == 0 && c.B == 255);

                if (visible) mask[y * w + x] = 1;
            }
            return mask;
        }
    }

    static int Pattern(byte[] m, int w, int x, int y)
    {
        int p = 0, bit = 0;

        for (int dy = 0; dy < 3; dy++)
        for (int dx = 0; dx < 3; dx++, bit++)
            if (m[(y + dy) * w + x + dx] != 0)
                p |= 1 << bit;

        return p;
    }

    static int Bits(int p)
    {
        int n = 0;
        while (p != 0) { n += p & 1; p >>= 1; }
        return n;
    }

    public static Target PrepareTarget(string path)
    {
        int w, h;
        byte[] mask = LoadMask(path, true, out w, out h);

        int total = 0;
        foreach (byte v in mask)
            if (v != 0) total++;

        int[] frequency = new int[512];

        for (int y = 0; y <= h - 3; y++)
        for (int x = 0; x <= w - 3; x++)
        {
            int p = Pattern(mask, w, x, y);
            frequency[p]++;
        }

        List<Anchor> candidates = new List<Anchor>();

        for (int y = 0; y <= h - 3; y++)
        for (int x = 0; x <= w - 3; x++)
        {
            int p = Pattern(mask, w, x, y);
            int bits = Bits(p);

            if (bits < 3 || bits > 7) continue;

            candidates.Add(new Anchor {
                X = x, Y = y,
                Pattern = p,
                Frequency = frequency[p]
            });
        }

        candidates.Sort((a,b) =>
            a.Frequency.CompareTo(b.Frequency));

        List<Anchor> selected = new List<Anchor>();

        foreach (Anchor a in candidates)
        {
            bool separated = true;

            foreach (Anchor s in selected)
            {
                if (Math.Abs(a.X-s.X) < 5 &&
                    Math.Abs(a.Y-s.Y) < 5)
                {
                    separated = false;
                    break;
                }
            }

            if (separated) selected.Add(a);
            if (selected.Count >= 12) break;
        }

        return new Target {
            Name = System.IO.Path.GetFileName(path),
            W = w, H = h, Total = total,
            Mask = mask, Anchors = selected
        };
    }

    public static RgbIndex BuildIndex(string path)
    {
        int w, h;
        byte[] mask = LoadMask(path, false, out w, out h);

        List<int>[] positions = new List<int>[512];

        for (int y = 0; y <= h - 3; y++)
        for (int x = 0; x <= w - 3; x++)
        {
            int p = Pattern(mask, w, x, y);

            if (positions[p] == null)
                positions[p] = new List<int>();

            positions[p].Add(y * w + x);
        }

        return new RgbIndex {
            W = w, H = h,
            Mask = mask,
            Positions = positions
        };
    }

    static Match Compare(Target a, RgbIndex b, int ox, int oy)
    {
        int x0 = Math.Max(0, ox);
        int y0 = Math.Max(0, oy);
        int x1 = Math.Min(b.W, ox + a.W);
        int y1 = Math.Min(b.H, oy + a.H);

        if (x1 <= x0 || y1 <= y0) return null;

        int inter = 0, countA = 0, countB = 0;

        for (int y = y0; y < y1; y++)
        for (int x = x0; x < x1; x++)
        {
            bool va = a.Mask[(y-oy)*a.W + (x-ox)] != 0;
            bool vb = b.Mask[y*b.W + x] != 0;

            if (va) countA++;
            if (vb) countB++;
            if (va && vb) inter++;
        }

        if (countA == 0 || countB == 0) return null;

        return new Match {
            X = ox,
            Y = oy,
            Intersection = inter,
            Coverage = (double)inter / a.Total,
            Precision = (double)inter / countB,
            IoU = (double)inter / (countA + countB - inter)
        };
    }

    public static List<Match> Find(Target a, RgbIndex b)
    {
        List<Anchor> usable = new List<Anchor>();

        foreach (Anchor anchor in a.Anchors)
        {
            List<int> list = b.Positions[anchor.Pattern];

            if (list != null && list.Count > 0)
                usable.Add(anchor);
        }

        usable.Sort((u,v) =>
            b.Positions[u.Pattern].Count.CompareTo(
            b.Positions[v.Pattern].Count));

        HashSet<long> tested = new HashSet<long>();
        List<Match> results = new List<Match>();

        int anchorsUsed = 0;

        foreach (Anchor anchor in usable)
        {
            List<int> positions = b.Positions[anchor.Pattern];

            // Evitar explosiones de candidatos por patrones comunes.
            if (positions.Count > 30000) continue;

            foreach (int pos in positions)
            {
                int px = pos % b.W;
                int py = pos / b.W;

                int ox = px - anchor.X;
                int oy = py - anchor.Y;

                long key = ((long)ox << 32) ^ (uint)oy;

                if (!tested.Add(key)) continue;

                Match r = Compare(a, b, ox, oy);

                if (r != null &&
                    r.Intersection >= 100 &&
                    r.Coverage >= 0.55 &&
                    r.Precision >= 0.80 &&
                    r.IoU >= 0.50)
                {
                    results.Add(r);
                }
            }

            anchorsUsed++;
            if (anchorsUsed >= 3) break;
        }

        results.Sort((u,v) => v.IoU.CompareTo(u.IoU));

        if (results.Count > 5)
            results.RemoveRange(5, results.Count - 5);

        return results;
    }
}
'@

Add-Type -TypeDefinition $codigo -ReferencedAssemblies System.Drawing -ErrorAction Stop

$base = "$env:USERPROFILE\Documents\RubyHeart_UMVC3"
$indexedDir = "$base\Original_MvC2\Indexed"
$rgbDir = "$base\Original_MvC2\RGB"

$rutaPendientes = "$base\Sprites_Pendientes.csv"
$rutaResultados = "$base\Resultados_Masivos.csv"
$rutaResumen = "$base\Resumen_Masivo.csv"

if (!(Test-Path $rutaPendientes)) {
    throw "No se encuentra Sprites_Pendientes.csv"
}

$pendientes = @(Import-Csv $rutaPendientes)
$rgbFiles = @(Get-ChildItem $rgbDir -Filter "*.png" |
    Sort-Object { [int]($_.BaseName -replace "^anim", "") })

if ($pendientes.Count -eq 0 -or $rgbFiles.Count -eq 0) {
    throw "No hay sprites pendientes o imágenes RGB."
}

Write-Host "`nPreparando $($pendientes.Count) sprites Indexed..."

$objetivos = [System.Collections.Generic.List[object]]::new()

foreach ($p in $pendientes) {
    $ruta = Join-Path $indexedDir $p.Indexed

    if (!(Test-Path $ruta)) {
        Write-Warning "No existe $($p.Indexed)"
        continue
    }

    $objetivos.Add(
        [BatchMaskMatcherV2]::PrepareTarget($ruta)
    )
}

Write-Host "Objetivos preparados: $($objetivos.Count)"
Write-Host "Imágenes RGB: $($rgbFiles.Count)"
Write-Host "`nIniciando búsqueda masiva..."

$resultados = [System.Collections.Generic.List[object]]::new()

for ($i = 0; $i -lt $rgbFiles.Count; $i++) {

    $archivo = $rgbFiles[$i]

    $indice = [BatchMaskMatcherV2]::BuildIndex(
        $archivo.FullName
    )

    foreach ($objetivo in $objetivos) {

        $coincidencias = [BatchMaskMatcherV2]::Find(
            $objetivo, $indice
        )

        foreach ($r in $coincidencias) {
            $resultados.Add([PSCustomObject]@{
                Indexed = $objetivo.Name
                RGB = $archivo.Name
                X = $r.X
                Y = $r.Y
                Interseccion = $r.Intersection
                Cobertura = [Math]::Round($r.Coverage * 100, 2)
                Precision = [Math]::Round($r.Precision * 100, 2)
                IoU = [Math]::Round($r.IoU * 100, 2)
            })
        }
    }

    if ((($i + 1) % 10) -eq 0 -or ($i + 1) -eq $rgbFiles.Count) {
        Write-Progress `
            -Activity "Buscando correspondencias" `
            -Status "$($i+1) de $($rgbFiles.Count) imágenes RGB" `
            -PercentComplete ((($i+1) / $rgbFiles.Count) * 100)

        Write-Host "Procesadas: $($i+1)/$($rgbFiles.Count) | Candidatos: $($resultados.Count)"
    }

    # Guardado de seguridad cada 25 imágenes RGB.
    if ((($i + 1) % 25) -eq 0 -and $resultados.Count -gt 0) {
        $resultados | Export-Csv $rutaResultados `
            -NoTypeInformation -Encoding UTF8
    }
}

Write-Progress -Activity "Buscando correspondencias" -Completed

if ($resultados.Count -gt 0) {
    $resultados |
        Sort-Object Indexed, @{Expression="IoU";Descending=$true} |
        Export-Csv $rutaResultados -NoTypeInformation -Encoding UTF8
} else {
    "Indexed,RGB,X,Y,Interseccion,Cobertura,Precision,IoU" |
        Set-Content $rutaResultados -Encoding UTF8
}

$grupos = $resultados | Group-Object Indexed
$resumen = foreach ($p in $pendientes) {

    $grupo = $grupos | Where-Object Name -eq $p.Indexed

    if ($null -ne $grupo) {
        $mejor = $grupo.Group |
            Sort-Object { [double]$_.IoU } -Descending |
            Select-Object -First 1

        [PSCustomObject]@{
            Indexed = $p.Indexed
            MejorRGB = $mejor.RGB
            X = $mejor.X
            Y = $mejor.Y
            Cobertura = $mejor.Cobertura
            Precision = $mejor.Precision
            IoU = $mejor.IoU
            Estado = "Candidato"
        }
    }
    else {
        [PSCustomObject]@{
            Indexed = $p.Indexed
            MejorRGB = ""
            X = ""
            Y = ""
            Cobertura = ""
            Precision = ""
            IoU = ""
            Estado = "Sin candidato"
        }
    }
}

$resumen | Export-Csv $rutaResumen -NoTypeInformation -Encoding UTF8

Write-Host "`n=== BUSQUEDA TERMINADA ==="
Write-Host "Candidatos encontrados: $($resultados.Count)"
Write-Host "Resultados: $rutaResultados"
Write-Host "Resumen: $rutaResumen"

$resumen | Format-Table -AutoSize
