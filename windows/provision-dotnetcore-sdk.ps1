# see https://dotnet.microsoft.com/download/dotnet-core/3.1
# see https://github.com/dotnet/core/blob/master/release-notes/3.1/3.1.12/3.1.406-download.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/cc28204e-58d7-4f2e-9539-aad3e71945d9/d4da77c35a04346cc08b0cacbc6611d5/dotnet-sdk-3.1.406-win-x64.exe'
$archiveHash = '6afc1916bd7be1488768ece0cc83c77d9962404f431331a7998a98385407dc7085fc04ccac2eeea1e28d38fdf870af71f61762e7d7b15c3a7ba56b6d6399d354'
$archiveName = Split-Path -Leaf $archiveUrl
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Downloading $archiveName..."
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA512).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host "Installing $archiveName..."
&$archivePath /install /quiet /norestart | Out-String -Stream
if ($LASTEXITCODE) {
    throw "Failed to install dotnetcore-sdk with Exit Code $LASTEXITCODE"
}
Remove-Item $archivePath

# reload PATH.
$env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$([Environment]::GetEnvironmentVariable('PATH', 'User'))"

# show information about dotnet.
dotnet --info

# install the sourcelink dotnet global tool.
dotnet tool install --global sourcelink
