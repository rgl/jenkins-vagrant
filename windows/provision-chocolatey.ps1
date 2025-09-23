# see https://community.chocolatey.org/packages/chocolatey
# renovate: datasource=nuget:chocolatey depName=chocolatey
$chocolateyVersion = '2.5.1'
$env:chocolateyVersion = $chocolateyVersion

Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
