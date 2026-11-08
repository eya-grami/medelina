<#
  crop-atelier.ps1
  Nettoie les captures d'écran de l'atelier : retire la barre de statut du
  téléphone et les bandes noires/grises, puis exporte des JPEG propres.

  Detection : une ligne est consideree comme "decor" (barre) si sa couleur
  moyenne est proche de la couleur du coin, ou si elle est uniforme et tres
  sombre (bande noire). Les grandes surfaces claires de la photo (mur blanc)
  restent donc dans le cadre.

  Usage :
    powershell -NoProfile -ExecutionPolicy Bypass -File .scratch/crop-atelier.ps1
#>
param(
  [string]$SrcDir    = "assets/atelier/src",
  [string]$OutDir    = "assets/atelier",
  [double]$BgTol     = 26,       # distance max a la couleur de fond pour etre "decor"
  [double]$VarLimit  = 300,      # variance max pour qu'une ligne proche du fond soit "decor"
  [double]$DarkLevel = 22,       # luminosite max pour une ligne uniforme "noire"
  [double]$MinRun    = 0.35,     # la bande photo doit couvrir au moins 35% de la hauteur
  [int]$MaxWidth     = 1400,
  [long]$Quality     = 88
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$src = Join-Path $PWD $SrcDir
$out = Join-Path $PWD $OutDir
if (-not (Test-Path $src)) {
  Write-Host "Dossier source introuvable : $src"
  exit 1
}
New-Item -ItemType Directory -Force -Path $out | Out-Null

function Get-LineStats {
  param($Thumb, [bool]$Vertical)
  $w = $Thumb.Width
  $h = $Thumb.Height
  $count = if ($Vertical) { $h } else { $w }
  $span = if ($Vertical) { $w } else { $h }
  $var = New-Object 'double[]' $count
  $mr = New-Object 'double[]' $count
  $mg = New-Object 'double[]' $count
  $mb = New-Object 'double[]' $count
  for ($i = 0; $i -lt $count; $i++) {
    $sr = 0.0; $sg = 0.0; $sb = 0.0
    $lumSum = 0.0; $lumSq = 0.0
    for ($j = 0; $j -lt $span; $j++) {
      $c = if ($Vertical) { $Thumb.GetPixel($j, $i) } else { $Thumb.GetPixel($i, $j) }
      $sr += $c.R; $sg += $c.G; $sb += $c.B
      $v = (0.299 * $c.R) + (0.587 * $c.G) + (0.114 * $c.B)
      $lumSum += $v; $lumSq += $v * $v
    }
    $mr[$i] = $sr / $span
    $mg[$i] = $sg / $span
    $mb[$i] = $sb / $span
    $mean = $lumSum / $span
    $var[$i] = ($lumSq / $span) - ($mean * $mean)
  }
  @{ Var = $var; R = $mr; G = $mg; B = $mb }
}

function Find-Band {
  param($Stats, [double]$BgR, [double]$BgG, [double]$BgB, [int]$MinLength)
  $n = $Stats.Var.Length
  $isBg = New-Object 'bool[]' $n
  for ($i = 0; $i -lt $n; $i++) {
    $dist = [Math]::Sqrt(
      [Math]::Pow($Stats.R[$i] - $BgR, 2) +
      [Math]::Pow($Stats.G[$i] - $BgG, 2) +
      [Math]::Pow($Stats.B[$i] - $BgB, 2))
    $lum = (0.299 * $Stats.R[$i]) + (0.587 * $Stats.G[$i]) + (0.114 * $Stats.B[$i])
    $isBg[$i] = (($dist -lt $BgTol) -and ($Stats.Var[$i] -lt $VarLimit)) -or (($lum -lt $DarkLevel) -and ($Stats.Var[$i] -lt 60))
  }
  $bestStart = 0; $bestLen = 0; $curStart = -1
  for ($i = 0; $i -lt $n; $i++) {
    if (-not $isBg[$i]) {
      if ($curStart -lt 0) { $curStart = $i }
      $len = ($i - $curStart) + 1
      if ($len -gt $bestLen) { $bestLen = $len; $bestStart = $curStart }
    }
    else { $curStart = -1 }
  }
  if ($bestLen -lt $MinLength) { return $null }
  [pscustomobject]@{ Start = $bestStart; Length = $bestLen }
}

function Test-SoftBg {
  param($Stats, [int]$i, [double]$BgR, [double]$BgG, [double]$BgB)
  $dist = [Math]::Sqrt(
    [Math]::Pow($Stats.R[$i] - $BgR, 2) +
    [Math]::Pow($Stats.G[$i] - $BgG, 2) +
    [Math]::Pow($Stats.B[$i] - $BgB, 2))
  $lum = (0.299 * $Stats.R[$i]) + (0.587 * $Stats.G[$i]) + (0.114 * $Stats.B[$i])
  return ((($dist -lt 45) -and ($Stats.Var[$i] -lt 400)) -or (($lum -lt 26) -and ($Stats.Var[$i] -lt 80)))
}

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1

$files = Get-ChildItem -Path $src -File |
  Where-Object { $_.Extension -match '^\.(png|jpe?g|bmp)$' } |
  Sort-Object Name

if (-not $files) {
  Write-Host "Aucune image trouvee dans $src (formats : png, jpg, bmp)."
  exit 1
}

$index = 0
foreach ($f in $files) {
  $index++
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  try {
    $tw = 100
    $th = [int][Math]::Round($img.Height * $tw / $img.Width)
    if ($th -lt 10) { $th = 10 }

    $thumb = New-Object System.Drawing.Bitmap $tw, $th
    $g = [System.Drawing.Graphics]::FromImage($thumb)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $tw, $th)
    $g.Dispose()

    # couleur de fond = moyenne des quatre coins (letterbox gris des captures)
    $cs = @(
      $thumb.GetPixel(3, 3),
      $thumb.GetPixel($tw - 4, 3),
      $thumb.GetPixel(3, $th - 4),
      $thumb.GetPixel($tw - 4, $th - 4)
    )
    $bgR = [double](($cs | Measure-Object -Property R -Average).Average)
    $bgG = [double](($cs | Measure-Object -Property G -Average).Average)
    $bgB = [double](($cs | Measure-Object -Property B -Average).Average)

    $rows = Get-LineStats -Thumb $thumb -Vertical $true
    $rowRun = Find-Band -Stats $rows -BgR $bgR -BgG $bgG -BgB $bgB -MinLength ([int][Math]::Max(8, $th * $MinRun))
    if ($rowRun) { $bandTop = $rowRun.Start; $bandH = $rowRun.Length }
    else { $bandTop = 0; $bandH = $th; Write-Host ("  ! {0} : aucune bande detectee, image gardee entiere" -f $f.Name) }
    if ($rowRun) {
      # rognage des restes de letterbox en haut et en bas
      $maxTrim = [int]($bandH * 0.4); $t = 0
      while (($t -lt $maxTrim) -and (($bandH - $t) -gt 60) -and (Test-SoftBg -Stats $rows -i $bandTop -BgR $bgR -BgG $bgG -BgB $bgB)) { $bandTop++; $bandH--; $t++ }
      $t = 0
      while (($t -lt $maxTrim) -and (($bandH - $t) -gt 60) -and (Test-SoftBg -Stats $rows -i ($bandTop + $bandH - 1) -BgR $bgR -BgG $bgG -BgB $bgB)) { $bandH--; $t++ }
    }

    $thumbBand = New-Object System.Drawing.Bitmap $tw, $bandH
    $gb = [System.Drawing.Graphics]::FromImage($thumbBand)
    $gb.DrawImage($thumb, 0, 0, (New-Object System.Drawing.Rectangle 0, $bandTop, $tw, $bandH), [System.Drawing.GraphicsUnit]::Pixel)
    $gb.Dispose()
    $cols = Get-LineStats -Thumb $thumbBand -Vertical $false
    $colRun = Find-Band -Stats $cols -BgR $bgR -BgG $bgG -BgB $bgB -MinLength ([int][Math]::Max(8, $tw * 0.5))
    if ($colRun) { $bandLeft = $colRun.Start; $bandW = $colRun.Length }
    else { $bandLeft = 0; $bandW = $tw }
    if ($colRun) {
      $maxTrimC = [int]($bandW * 0.4); $tc = 0
      while (($tc -lt $maxTrimC) -and (($bandW - $tc) -gt 60) -and (Test-SoftBg -Stats $cols -i $bandLeft -BgR $bgR -BgG $bgG -BgB $bgB)) { $bandLeft++; $bandW--; $tc++ }
      $tc = 0
      while (($tc -lt $maxTrimC) -and (($bandW - $tc) -gt 60) -and (Test-SoftBg -Stats $cols -i ($bandLeft + $bandW - 1) -BgR $bgR -BgG $bgG -BgB $bgB)) { $bandW--; $tc++ }
    }

    $sx = $img.Width / $tw
    $sy = $img.Height / $th
    $cropX = [int][Math]::Round($bandLeft * $sx)
    $cropY = [int][Math]::Round($bandTop * $sy)
    $cropW = [int][Math]::Round($bandW * $sx)
    $cropH = [int][Math]::Round($bandH * $sy)
    if ($cropW -lt 40 -or $cropH -lt 40) {
      $cropX = 0; $cropY = 0; $cropW = $img.Width; $cropH = $img.Height
      Write-Host ("  ! {0} : recadrage trop petit, image gardee entiere" -f $f.Name)
    }
    if (($cropX + $cropW) -gt $img.Width) { $cropW = $img.Width - $cropX }
    if (($cropY + $cropH) -gt $img.Height) { $cropH = $img.Height - $cropY }

    $outW = [Math]::Min($cropW, $MaxWidth)
    $outH = [int][Math]::Round($cropH * $outW / $cropW)

    $canvas = New-Object System.Drawing.Bitmap $outW, $outH
    $canvas.SetResolution(96, 96)
    $gc = [System.Drawing.Graphics]::FromImage($canvas)
    $gc.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gc.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $gc.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $outW, $outH), (New-Object System.Drawing.Rectangle $cropX, $cropY, $cropW, $cropH), [System.Drawing.GraphicsUnit]::Pixel)
    $gc.Dispose()

    $name = "atelier-{0:00}.jpg" -f $index
    $dest = Join-Path $out $name
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
    $canvas.Save($dest, $codec, $ep)
    $canvas.Dispose()
    $thumbBand.Dispose()
    $thumb.Dispose()

    $kb = [int]((Get-Item $dest).Length / 1KB)
    Write-Host ("{0,-14} {1}x{2}  ->  {3}  {4}x{5}  {6} Ko  (coupe y:{7} h:{8})" -f $f.Name, $img.Width, $img.Height, $name, $outW, $outH, $kb, $cropY, $cropH)
  }
  finally {
    $img.Dispose()
  }
}

Write-Host ""
Write-Host "$index image(s) recadree(s) dans $out"
