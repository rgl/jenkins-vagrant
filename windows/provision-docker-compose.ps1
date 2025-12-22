# download install the docker-compose binaries.
# see https://github.com/docker/compose/releases
# renovate: datasource=github-releases depName=docker/compose
$archiveVersion = '5.0.1'
$archiveUrl = "https://github.com/docker/compose/releases/download/v$archiveVersion/docker-compose-windows-x86_64.exe"
$archiveName = Split-Path -Leaf $archiveUrl
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker-compose $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$dockerCliPluginsPath = "$env:ProgramData\docker\cli-plugins"
mkdir -Force $dockerCliPluginsPath | Out-Null
Move-Item -Force $archivePath "$dockerCliPluginsPath\docker-compose.exe"
# ensure that all the plugins inherit the parent directory permissions.
# NB this ensures that any user can execute the plugins.
Import-Module Carbon
Get-ChildItem -Recurse $dockerCliPluginsPath | ForEach-Object {
    Enable-CAclInheritance $_.FullName
}
# try the binary.
docker compose version
