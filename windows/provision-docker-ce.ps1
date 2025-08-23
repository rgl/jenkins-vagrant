param(
    [Parameter(Mandatory=$true)]
    [string]$domain = 'windows.jenkins.example.com'
)

# see https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-docker/configure-docker-daemon
# see https://docs.docker.com/engine/installation/linux/docker-ce/binaries/#install-server-and-client-binaries-on-windows
# see https://github.com/moby/moby/releases/tag/v28.3.3
# see https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/tag/v28.3.3

# download install the docker binaries.
# renovate: datasource=github-releases depName=rgl/docker-ce-windows-binaries-vagrant
$archiveVersion = '28.3.3'
$archiveName = "docker-$archiveVersion.zip"
$archiveUrl = "https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/download/v$archiveVersion/$archiveName"
$archivePath = "$env:TEMP\$archiveName"
Write-Host "Installing docker $archiveVersion..."
(New-Object System.Net.WebClient).DownloadFile($archiveUrl, $archivePath)
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
Write-Title "configuring docker"
$configPath = "$env:ProgramData\docker\config"
mkdir -Force $configPath | Out-Null
Copy-Item "c:\vagrant\tmp\jenkins-ca\$domain-key.pem" $configPath
Copy-Item "c:\vagrant\tmp\jenkins-ca\$domain-crt.pem" $configPath
Copy-Item "c:\vagrant\tmp\jenkins-ca\jenkins-ca-crt.pem" $configPath
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
        'npipe:////./pipe/docker_engine',
        'tcp://0.0.0.0:2376'
    )
    'tlsverify' = $true
    'tlskey' = "$configPath\$domain-key.pem"
    'tlscert' = "$configPath\$domain-crt.pem"
    'tlscacert' = "$configPath\jenkins-ca-crt.pem"
}
Set-Content -Encoding ascii "$configPath\daemon.json" ($config | ConvertTo-Json -Depth 100)

Write-Title 'starting docker'
Start-Service docker

Write-Host 'Creating the firewall rule to allow inbound TCP/IP access to the Docker Engine port 2376...'
New-NetFirewallRule `
    -Name 'Docker-Engine-In-TCP' `
    -DisplayName 'Docker Engine (TCP-In)' `
    -Direction Inbound `
    -Enabled True `
    -Protocol TCP `
    -LocalPort 2376 `
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

Write-Title 'docker version (https)'
docker `
    --tlsverify `
    --tlskey c:\vagrant\tmp\jenkins-ca\jenkins-key.pem `
    --tlscert c:\vagrant\tmp\jenkins-ca\jenkins-crt.pem `
    --tlscacert c:\vagrant\tmp\jenkins-ca\jenkins-ca-crt.pem `
    --host "tcp://${domain}:2376" `
    version

Write-Title 'docker version (named pipe)'
docker version

Write-Title 'docker info (named pipe)'
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
