# see https://dotnet.microsoft.com/en-us/download/dotnet/10.0
# see https://github.com/dotnet/core/blob/main/release-notes/10.0/10.0.9/10.0.9.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.301/dotnet-sdk-10.0.301-win-x64.exe'
$archiveHash = '96b7793f0d1f40d8a8a05f9f076d6f4146045429ae2ca17906f109d8747ac34826d9775ffbd0afd9b01bc84bac1a3dba02a6d86af08fe2809276c3e3ffa49098'
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
    throw "Failed to install dotnet-sdk with Exit Code $LASTEXITCODE"
}
Remove-Item $archivePath

# reload PATH.
$env:PATH = "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$([Environment]::GetEnvironmentVariable('PATH', 'User'))"

# show information about dotnet.
dotnet --info
