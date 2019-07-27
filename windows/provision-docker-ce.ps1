# see https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-docker/configure-docker-daemon
# see https://docs.docker.com/engine/installation/linux/docker-ce/binaries/#install-server-and-client-binaries-on-windows
# see https://github.com/docker/docker-ce/releases/tag/v19.03.1

# download install the docker binaries.
$archiveVersion = '19.03.1'
$archiveName = "docker-$archiveVersion.zip"
$archiveUrl = "https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/download/v$archiveVersion/$archiveName"
$archiveHash = '1097a9e7765b0b6ba6d8a02f7ce0a76571f23b4c5e9b4223c74c7c1f15cb934b'
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveActualHash -ne $archiveHash) {
    throw "the $archiveUrl file hash $archiveActualHash does not match the expected $archiveHash"
}
Expand-Archive $archivePath -DestinationPath $env:ProgramFiles
Remove-Item $archivePath

# add docker to the Machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$env:ProgramFiles\docker",
    'Machine')
# add docker to the current process PATH.
$env:PATH += ";$env:ProgramFiles\docker"

# install the docker service.
dockerd --register-service

# add group that will be allowed to use the docker engine named pipe.
New-LocalGroup `
    -Name docker-users `
    -Description 'Docker engine users' `
    | Out-Null

# configure docker through a configuration file.
# see https://docs.docker.com/engine/reference/commandline/dockerd/#windows-configuration-file
$config = @{
    'experimental' = $false
    'debug' = $false
    'labels' = @('os=windows')
    'exec-opts' = @('isolation=process')
    # allow users in the following groups to use the docker engine named pipe.
    # see https://github.com/moby/moby/commit/0906195fbbd6f379c163b80f23e4c5a60bcfc5f0
    # see https://github.com/moby/moby/blob/8e610b2b55bfd1bfa9436ab110d311f5e8a74dcb/daemon/listeners/listeners_windows.go#L25
    'group' = 'docker-users'
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
# see https://hub.docker.com/_/microsoft-windows-nanoserver
# see https://hub.docker.com/_/microsoft-windows-servercore
# see https://hub.docker.com/_/microsoft-windowsfamily-windows
Write-Host 'Pulling base image...'
docker pull mcr.microsoft.com/windows/nanoserver:1809
#docker pull mcr.microsoft.com/windows/servercore:1809
#docker pull mcr.microsoft.com/windows/servercore:ltsc2019
#docker pull mcr.microsoft.com/windows:1809
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

Write-Title 'docker named pipe \\.\pipe\docker_engine ACL'
# NB you can get the current list of named pipes with:
#       [System.IO.Directory]::GetFiles('\\.\pipe\') | Sort-Object
# NB you can manually change the named pipe ACL with:
#       Add-LocalGroupMember -Group docker-users -Member jenkins
#       $ac = [System.IO.Directory]::GetAccessControl('\\.\pipe\docker_engine')
#       $ac.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule 'docker-users','Read,Write,Synchronize','Allow'))
#       [System.IO.Directory]::SetAccessControl('\\.\pipe\docker_engine', $ac)
[System.IO.Directory]::GetAccessControl("\\.\pipe\docker_engine") | Format-Table -Wrap

# see https://docs.docker.com/engine/api/v1.40/
# see https://github.com/moby/moby/tree/master/api
Write-Title 'docker info (obtained from http://localhost:2375/info)'
$infoResponse = Invoke-WebRequest 'http://localhost:2375/info' -UseBasicParsing
$info = $infoResponse.Content | ConvertFrom-Json
Write-Output "Engine Version:     $($info.ServerVersion)"
Write-Output "Engine Api Version: $($infoResponse.Headers['Api-Version'])"
