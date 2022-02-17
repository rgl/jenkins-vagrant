# Copy files from the vagrant shared directory to the local disk.
# NB this is needed due to docker build failing with:
#       unable to prepare context: unable to evaluate symlinks in context path: CreateFile
#       \\192.168.1.69\vgt-0aab8fa734c4edb0eb1969bf3a4502ba-6ad5fdbcbf2eaa93bd62f92333a2e6e5windows:
#       The network name cannot be found.
mkdir -Force "$env:TEMP\portainer" | Out-Null
copy * "$env:TEMP\portainer"
cd "$env:TEMP\portainer"

Write-Output 'starting portainer...'
$hostIp = (Get-NetAdapter -Name 'Ethernet*' | Sort-Object -Property Name | Select-Object -Last 1 | Get-NetIPAddress -AddressFamily IPv4).IPAddress
#$hostIp = (Get-NetAdapter -Name 'vEthernet (nat)' | Get-NetIPAddress -AddressFamily IPv4).IPAddress
docker `
    run `
    --name portainer `
    --restart unless-stopped `
    -d `
    -v //./pipe/docker_engine://./pipe/docker_engine `
    -p 9000:9000 `
    portainer/portainer-ce:2.11.1 `
        -H npipe:////./pipe/docker_engine

$url = 'http://localhost:9000'
Write-Output "Using the container by doing an http request to $url..."
(Invoke-RestMethod $url) -split '\n' | Select-Object -First 8 | ForEach-Object {"    $_"}

Write-Output "Portainer is available at http://${hostIp}:9000"
Write-Output 'Or inside the VM at http://localhost:9000'
