param(
    [Parameter(Mandatory=$true)]
    [string]$script,

    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$scriptArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    $command, $commandArguments = $Arguments
    if ($command -eq 'install') {
        $Arguments = @($command, '--no-progress') + $commandArguments
    }
    for ($n = 0; $n -lt 10; ++$n) {
        if ($n) {
            # NB sometimes choco fails with "The package was not found with the source(s) listed."
            #    but normally its just really a transient "network" error.
            Write-Host "Retrying choco install..."
            Start-Sleep -Seconds 3
        }
        &C:\ProgramData\chocolatey\bin\choco.exe @Arguments
        if ($SuccessExitCodes -Contains $LASTEXITCODE) {
            return
        }
    }
    throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
}
function choco {
    Start-Choco $Args
}

function Get-DotNetVersion {
    # see https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed#net_d
    $release = [int](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if ($release -ge 461808) {
        return '4.7.2 or later'
    }
    if ($release -ge 461308) {
        return '4.7.1'
    }
    if ($release -ge 460798) {
        return '4.7'
    }
    if ($release -ge 394802) {
        return '4.6.2'
    }
    if ($release -ge 394254) {
        return '4.6.1'
    }
    if ($release -ge 393295) {
        return '4.6'
    }
    if ($release -ge 379893) {
        return '4.5.2'
    }
    if ($release -ge 378675) {
        return '4.5.1'
    }
    if ($release -ge 378389) {
        return '4.5'
    }
    return 'No 4.5 or later version detected'
}

Set-Location c:\vagrant\windows

$script = Resolve-Path $script

Set-Location (Split-Path -Parent $script)

Write-Host "Running $script..."

. ".\$(Split-Path -Leaf $script)" @scriptArguments
