# see https://github.com/genuinetools/reg

$archiveVersion = '0.16.1'
$archiveName = 'docker-reg.exe'
$archiveUrl = "https://github.com/genuinetools/reg/releases/download/v$archiveVersion/reg-windows-amd64"
$archiveHash = '23b2a4dd07c88552e98ac37c2cf2ce8fbbd4dc396cf6d1cc1743fa65a6d4565c'
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
