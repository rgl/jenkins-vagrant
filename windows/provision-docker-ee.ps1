# see https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-docker/configure-docker-daemon

# install docker ee for Windows Server.
# see https://docs.docker.com/install/windows/docker-ee/
# see https://store.docker.com/editions/enterprise/docker-ee-server-windows
# see https://github.com/OneGet/MicrosoftDockerProvider
# see dockerURL variable at https://github.com/OneGet/MicrosoftDockerProvider/blob/developer/DockerMsftProvider.psm1#L21
# NB docker-ee is free to use in Windows Server (its included in the Windows license).
$dockerVersion = '19.03'
Write-Host "Installing docker $dockerVersion..."
Get-PackageProvider -Name NuGet -Force | Out-Null # NB the Get-* cmdlet really installs the NuGet package provider...
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force -RequiredVersion $dockerVersion | Out-Null

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

# NB unfortunatelly docker is automatically started, so we have to stop 
#    it before making the configuration...
#    see https://github.com/OneGet/MicrosoftDockerProvider/issues/52
Write-Host 'Stopping docker...'
Stop-Service docker

# configure docker through a configuration file.
# see https://docs.docker.com/engine/reference/commandline/dockerd/#windows-configuration-file
$config = @{
    'experimental' = $false
    'debug' = $false
    'labels' = @('os=windows')
    'exec-opts' = @('isolation=process')
    'hosts' = @(
        'tcp://0.0.0.0:2375',
        'npipe:////./pipe/docker_engine'
    )
}
mkdir -Force "$env:ProgramData\docker\config" | Out-Null
Set-Content -Encoding ascii "$env:ProgramData\docker\config\daemon.json" ($config | ConvertTo-Json)

Write-Host 'Starting docker...'
Start-Service docker

# see https://blogs.technet.microsoft.com/virtualization/2018/10/01/incoming-tag-changes-for-containers-in-windows-server-2019/
# see https://hub.docker.com/r/microsoft/nanoserver
Write-Host 'Pulling base image...'
docker pull mcr.microsoft.com/windows/nanoserver:1809
#docker pull mcr.microsoft.com/windows/servercore:1809
#docker pull mcr.microsoft.com/windows/windows:1809
#docker pull mcr.microsoft.com/windows/servercore:ltsc2019
#docker pull microsoft/dotnet:2.1-sdk-nanoserver-1809
#docker pull microsoft/dotnet:2.1-aspnetcore-runtime-nanoserver-1809

Write-Host 'Creating the firewall rule to allow inbound TCP/IP access to the Docker Engine port 2375...'
New-NetFirewallRule `
    -Name 'Docker-Engine-In-TCP' `
    -DisplayName 'Docker Engine (TCP-In)' `
    -Direction Inbound `
    -Enabled True `
    -Protocol TCP `
    -LocalPort 2375 `
    | Out-Null

Write-Title "windows version"
$windowsCurrentVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$windowsVersion = "$($windowsCurrentVersion.CurrentMajorVersionNumber).$($windowsCurrentVersion.CurrentMinorVersionNumber).$($windowsCurrentVersion.CurrentBuildNumber).$($windowsCurrentVersion.UBR)"
Write-Output $windowsVersion

Write-Title 'windows BuildLabEx version'
# BuildLabEx is something like:
#      17763.1.amd64fre.rs5_release.180914-1434
#      ^^^^^^^ ^^^^^^^^ ^^^^^^^^^^^ ^^^^^^ ^^^^
#      build   platform branch      date   time (redmond tz)
# see https://channel9.msdn.com/Blogs/One-Dev-Minute/Decoding-Windows-Build-Numbers
(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name BuildLabEx).BuildLabEx

Write-Title 'docker version'
docker version

Write-Title 'docker info'
docker info

# see https://docs.docker.com/engine/api/v1.40/
# see https://github.com/moby/moby/tree/master/api
Write-Title 'docker info (obtained from http://localhost:2375/info)'
$infoResponse = Invoke-WebRequest 'http://localhost:2375/info' -UseBasicParsing
$info = $infoResponse.Content | ConvertFrom-Json
Write-Output "Engine Version:     $($info.ServerVersion)"
Write-Output "Engine Api Version: $($infoResponse.Headers['Api-Version'])"
