#<
# add-profile-image.ps1
# Usage: .\add-profile-image.ps1 -SourcePath "C:\Users\You\Downloads\myphoto.jpg" [-ResizeWidth 400] [-Quality 85]
#
# This script copies the provided image into the project's images folder as profile.jpg and
# optionally resizes/compresses it for web use.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$SourcePath,

    [Parameter(Mandatory=$false)]
    [string]$Destination = "$PSScriptRoot\images\profile.jpg",

    [Parameter(Mandatory=$false)]
    [int]$ResizeWidth = 400,

    [Parameter(Mandatory=$false)]
    [int]$Quality = 85
)

if (-not (Test-Path -Path $SourcePath -PathType Leaf)) {
    Write-Error "Source file not found: $SourcePath"
    exit 1
}

$destDir = Split-Path -Path $Destination -Parent
if (-not (Test-Path -Path $destDir)) {
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
}

Copy-Item -Path $SourcePath -Destination $Destination -Force
Write-Output "Copied: $SourcePath -> $Destination"

# If ResizeWidth is provided and the destination is an image we can handle, resize it.
try {
    Add-Type -AssemblyName System.Drawing
} catch {
    Write-Warning "Could not load System.Drawing. Skipping resize step."
    exit 0
}

$ext = [IO.Path]::GetExtension($Destination).ToLowerInvariant()
if ($ext -notin '.jpg','.jpeg','.png') {
    Write-Output "Unsupported image type for resizing: $ext. Skipping resize."
    exit 0
}

try {
    $img = [System.Drawing.Image]::FromFile($Destination)
} catch {
    Write-Warning "Failed to load image for resizing: $Destination"
    exit 0
}

if ($ResizeWidth -le 0) {
    # Nothing to do
    $img.Dispose()
    exit 0
}

# calculate new size keeping aspect ratio
$ratio = [double]$ResizeWidth / $img.Width
if ($ratio -ge 1) {
    Write-Output "Image is smaller than or equal to target width ($ResizeWidth). Skipping resize."
    $img.Dispose()
    exit 0
}

$newWidth = [int]$ResizeWidth
$newHeight = [int]([Math]::Round($img.Height * $ratio))

$thumb = New-Object System.Drawing.Bitmap $newWidth, $newHeight
$graphics = [System.Drawing.Graphics]::FromImage($thumb)
$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.DrawImage($img, 0, 0, $newWidth, $newHeight)

try {
    if ($ext -in '.jpg','.jpeg') {
        $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int]$Quality)
        $thumb.Save($Destination, $encoder, $encoderParams)
    } else {
        # For PNG keep lossless save (no quality parameter)
        $thumb.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    Write-Output "Resized and saved: $Destination ($newWidth x $newHeight)"
} catch {
    Write-Warning "Failed to save resized image: $_"
} finally {
    $graphics.Dispose()
    $thumb.Dispose()
    $img.Dispose()
}
