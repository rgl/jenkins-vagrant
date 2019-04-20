# NB this script run as the jenkins user and does not have access to C:\vagrant.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# to use the execute shell build step add msys2 to the PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'User'));C:\tools\msys64\usr\bin",
    'User')

# configure git.
git config --global user.email 'jenkins@example.com'
git config --global user.name 'Jenkins'
git config --global http.sslbackend schannel
git config --global push.default simple
git config --global core.autocrlf false

# install the sourcelink dotnet global tool.
# NB this is installed at %USERPROFILE%\.dotnet\tools.
# see https://github.com/dotnet/sourcelink
dotnet tool install --global sourcelink

# install the xUnit to JUnit report converter.
# see https://github.com/gabrielweyer/xunit-to-junit
dotnet tool install --global dotnet-xunit-to-junit
