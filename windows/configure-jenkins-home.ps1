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

# install the sourcelink dotnet global tool.
# NB this is installed at %USERPROFILE%\.dotnet\tools.
dotnet tool install --global sourcelink
