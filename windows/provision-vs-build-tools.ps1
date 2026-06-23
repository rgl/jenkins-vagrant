# add support for building applications that target the .net framework 4.8.1.
# see https://community.chocolatey.org/packages/netfx-4.8.1-devpack
choco install -y netfx-4.8.1-devpack

# install the Visual Studio Build Tools 2026 18.7.1.
# see https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-history#release-dates-and-build-numbers
# see https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes
# see https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/command-line-parameter-examples?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=visualstudio
# see https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio
# NB update the windbg version in provision-procdump-as-postmortem-debugger.ps1 to match the installed Windows11SDK.26100.
$archiveUrl = 'https://download.visualstudio.microsoft.com/download/pr/a95b7880-2074-4c46-bdbf-e1b8c547ac60/f45aacf4e0364acfd67be3d55cde3e5269144c83a9621b758526d83d2aedcdcb/vs_BuildTools.exe'
$archiveHash = 'f45aacf4e0364acfd67be3d55cde3e5269144c83a9621b758526d83d2aedcdcb'
$archiveName = Split-Path $archiveUrl -Leaf
$archivePath = "$env:TEMP\$archiveName"
Write-Host 'Downloading the Visual Studio Build Tools Setup Bootstrapper...'
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
}
Write-Host 'Installing the Visual Studio Build Tools...'
$vsBuildToolsHome = 'C:\VS2026BuildTools'
for ($try = 1; ; ++$try) {
    &$archivePath `
        --installPath $vsBuildToolsHome `
        --add Microsoft.VisualStudio.Workload.MSBuildTools `
        --add Microsoft.VisualStudio.Workload.VCTools `
        --add Microsoft.VisualStudio.Component.VC.CLI.Support `
        --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        --add Microsoft.VisualStudio.Component.Windows11SDK.26100 `
        --norestart `
        --quiet `
        --wait `
        | Out-String -Stream
    if ($LASTEXITCODE) {
        if ($try -le 5) {
            Write-Host "Failed to install the Visual Studio Build Tools with Exit Code $LASTEXITCODE. Trying again (hopefully the error was transient)..."
            Start-Sleep -Seconds 10
            continue
        }
        throw "Failed to install the Visual Studio Build Tools with Exit Code $LASTEXITCODE"
    }
    break
}

# add MSBuild to the machine PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$vsBuildToolsHome\MSBuild\Current\Bin",
    'Machine')

# prevent msbuild from running in background, as that will interfere with
# cleaning the job workspace due to open files/directories.
[Environment]::SetEnvironmentVariable(
    'MSBUILDDISABLENODEREUSE',
    '1',
    'Machine')
