# see https://dotnet.microsoft.com/download/dotnet-core/2.1
# see https://github.com/dotnet/core/blob/master/release-notes/2.1/2.1.9/2.1.9.md

# opt-out from dotnet telemetry.
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'

# install the dotnet sdk.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/4690d405-11c6-488e-b1ba-4f2e9b247b25/7c70d9003e02997b66d843ec54ba53d1/dotnet-sdk-2.1.505-win-x64.exe'
$archiveHash = 'bb93a14aff94fcffe55cce9393690a58f8e7707d56b4c309ce809d61f09a54f67b1a16690d6a71a902ec45ab1d2696ee2f0df88dff00fdd7605ca577e7c3983b'
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

# make sure the SYSTEM account PATH environment variable is empty because,
# for some reason, the sdk setup changes it to include private directories
# which cannot be accessed by anyone but the user that installed the sdk.
# see https://github.com/dotnet/core/issues/1942.
# NB the .DEFAULT key is for the local SYSTEM account (S-1-5-18).
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
New-ItemProperty `
    -Path HKU:\.DEFAULT\Environment `
    -Name Path `
    -Value '' `
    -PropertyType ExpandString `
    -Force `
    | Out-Null
Remove-PSDrive HKU
