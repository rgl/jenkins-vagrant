# see https://github.com/vmware/govmomi/releases
# renovate: datasource=github-releases depName=vmware/govmomi
$version = '0.56.0'

$archiveUrl = "https://github.com/vmware/govmomi/releases/download/v${version}/govc_Windows_x86_64.zip"
$govc = "$env:ChocolateyInstall\bin\govc.exe"

# bail when its already installed.
# e.g. govc 0.39.0
if ((Test-Path $govc) -and ((&$govc version) -match '^govc (.+)')) {
    $actualVersionValue = $Matches[1]
    if ($actualVersionValue -eq $version) {
        Exit 0
    }
}

# download and install.
Write-Host "Downloading $archiveUrl..."
$tempPath = "$env:TEMP\govc-${version}"
$archivePath = "$tempPath\govc-${version}.zip"
if (Test-Path $tempPath) {
    Remove-Item -Recurse $tempPath
}
mkdir $tempPath | Out-Null
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
Expand-Archive $archivePath $tempPath
Copy-Item "$tempPath\govc.exe" $govc
Remove-Item -Recurse $tempPath
