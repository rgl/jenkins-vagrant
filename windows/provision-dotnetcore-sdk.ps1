# see https://dotnet.microsoft.com/download/dotnet-core/3.1
# see https://github.com/dotnet/core/blob/main/release-notes/3.1/3.1.14/3.1.408-download.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/fa20039c-5871-4597-8a7b-f0553a12edcc/4fb1cce6214049fe639dd230a9265133/dotnet-sdk-3.1.408-win-x64.exe'
$archiveHash = 'c8d3000f07735ee7cdf3bab402323bf96413d7afd7dadc5f1e92f02c184b67ca00f188e083f1d6bd8ae21b88a24f87d443088ecee28c33cd186f8ca9606fc816'
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

# add the nuget.org source.
# see https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-nuget-add-source
dotnet nuget add source --name nuget.org https://api.nuget.org/v3/index.json
dotnet nuget list source

# install the sourcelink dotnet global tool.
dotnet tool install --global sourcelink
