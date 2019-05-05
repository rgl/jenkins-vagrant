# see https://github.com/genuinetools/reg

$archiveVersion = '0.16.0'
$archiveName = 'docker-reg.exe'
$archiveUrl = "https://github.com/genuinetools/reg/releases/download/v$archiveVersion/reg-windows-amd64"
$archiveHash = 'aec2ba84a2de95a21f1649e0f398ecf91575c1e1b8994e9589a28d2e32ce2cd8'
$archivePath = "$env:TEMP\$archiveName"

Write-Host 'Downloading docker-reg...'
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}

Write-Host 'Installing docker-reg...'
Move-Item $archivePath "$env:ProgramFiles\docker"

Write-Host 'docker-reg version:'
docker-reg.exe version

Write-Host 'docker-reg examples:'
Write-Host '  docker-reg manifest -d mcr.microsoft.com/nanoserver'
Write-Host '  docker-reg manifest -d mcr.microsoft.com/windows/nanoserver'
Write-Host '  docker-reg tags -d mcr.microsoft.com/windows/nanoserver'
Write-Host '  docker-reg tags -d mcr.microsoft.com/windows/servercore'
Write-Host '  docker-reg tags -d mcr.microsoft.com/windowsfamily/windows'
