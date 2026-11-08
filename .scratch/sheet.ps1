Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem "$PWD/assets/atelier" -Filter *.jpg | Sort-Object Name
$cols = 4; $cw = 290; $ch = 380
$rows = [Math]::Ceiling($files.Count / $cols)
$bmp = New-Object System.Drawing.Bitmap ($cols*$cw), ($rows*$ch)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(25,25,25))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font "Consolas", 13
$n = 0
foreach ($f in $files) {
  $c = $n % $cols; $r = [Math]::Floor($n / $cols)
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $scale = [Math]::Min(($cw-14)/$img.Width, ($ch-34)/$img.Height)
  $w = [int]($img.Width*$scale); $h = [int]($img.Height*$scale)
  $x = $c*$cw + ($cw-$w)/2; $y = $r*$ch + 26 + (($ch-30)-$h)/2
  $g.DrawRectangle([System.Drawing.Pens]::DarkOrange, [int]$x, [int]$y, $w, $h)
  $g.DrawImage($img, $x, $y, $w, $h)
  $g.DrawString(("{0} {1}x{2}" -f $f.BaseName.Substring(8), $img.Width, $img.Height), $font, [System.Drawing.Brushes]::White, ($c*$cw + 6), ($r*$ch + 4))
  $img.Dispose(); $n++
}
$g.Dispose()
$small = New-Object System.Drawing.Bitmap 1160, ([int](($rows*$ch) * 1160 / ($cols*$cw)))
$g2 = [System.Drawing.Graphics]::FromImage($small)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.DrawImage($bmp, 0, 0, $small.Width, $small.Height)
$g2.Dispose(); $bmp.Dispose()
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]84)
$small.Save("$PWD/.scratch/sheet.jpg", $codec, $ep)
$small.Dispose()
"$([int]((Get-Item "$PWD/.scratch/sheet.jpg").Length/1KB)) Ko"
