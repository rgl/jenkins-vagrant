# see https://unity3d.com/get-unity/download/archive
# see the Testing & Automation forum at https://forum.unity.com/forums/testing-automation.211/

$archiveUrl = 'https://public-cdn.cloud.unity3d.com/hub/prod/UnityHubSetup.exe'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Output 'Downloading Unity Hub...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
Write-Output 'Installing Unity Hub...'
&$archivePath /S | Out-String -Stream

Write-Output 'Installing Unity Editor...'
choco install -y unity --version 2019.1.12

Write-Output 'Unity is installed, but You still need to manually activate it using the Unity Hub. See the README.md file.'
