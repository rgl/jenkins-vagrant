choco install -y procdump


#
# create the dumps storage directory.
# NB the dumps in this directory can be analysed with:
#       * cdb/WinDbg https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools
#       * https://github.com/x64dbg/x64dbg
#       * Visual Studio Debugger
#       * https://github.com/Dynatrace/superdump
#       * Breakpad https://github.com/google/breakpad
#         https://chromium.googlesource.com/breakpad/breakpad
#         https://github.com/getsentry/build-pad/releases

# grant the SYSTEM and Administrators accounts Full permissions.
$dumpsDirectory = mkdir -Force c:\dumps
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
@(
    'SYSTEM'
    'Administrators'
) | ForEach-Object {
    $acl.AddAccessRule((
        New-Object `
            Security.AccessControl.FileSystemAccessRule(
                $_,
                'FullControl',
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow')))
}
$dumpsDirectory.SetAccessControl($acl)


#
# install procdump as the AeDebug postmortem debugger.
# see https://docs.microsoft.com/en-us/windows/desktop/debug/configuring-automatic-debugging
# see https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/enabling-postmortem-debugging
# see https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/user-mode-dump-files
# see Hardcore Debugging (TechEd North America 2014) at https://channel9.msdn.com/Events/TechEd/NorthAmerica/2014/WIN-B412
# NB due to interactions with WER something you'll get two dumps for the same process, which is sad but true.
# NB you still need to periodically manage the size of c:\dumps by deleting files from there.
# NB Only -mm, -ma, -mp, -mc, -md and -r are supported as additional options.
# NB Uninstall (-u only) restores the previous configuration (from ProcDump registry sub-key).
# NB this will install procdump as the system just-in-time (AeDebug) debugger at:
#       Set to:
#         HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AeDebug
#           (REG_SZ) Auto     = 1
#           (REG_SZ) Debugger = "C:\ProgramData\chocolatey\lib\procdump\tools\procdump.exe" -accepteula -mp -j "c:\dumps" %ld %ld %p
#       Set to:
#         HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\AeDebug
#           (REG_SZ) Auto     = 1
#           (REG_SZ) Debugger = "C:\ProgramData\chocolatey\lib\procdump\tools\procdump.exe" -accepteula -mp -j "c:\dumps" %ld %ld %p
# NB this is complimentary to the Windows Error Reporting (WER) (https://docs.microsoft.com/en-us/windows/win32/wer/windows-error-reporting) machinery.
#    NB WER is disabled bellow.
# TODO see why that when an application is started from msys2/cygwin it does not trigger AeDebug/procmon.
# TODO manage the contents/size of the dumps directory.

procdump -mp -i $dumpsDirectory.FullName


#
# disable Windows Error Reporting (WER).

Set-ItemProperty `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' `
    -Name Disabled `
    -Value 1


#
# install the debugging tools for windows.
# NB to print basic information about a mini dump use:
#       &"C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe" -nosqm -z C:\dumps\raise-illegal-instruction-c.exe_190801_184222.dmp -c '!peb;q'
#    see https://docs.microsoft.com/en-us/windows-hardware/drivers/debugger/extracting-information-from-a-dump-file
# NB this should correspond to Microsoft.VisualStudio.Component.Windows10SDK.19041 as installed by vs build tools in provision-vs-build-tools.ps1.
choco install -y windows-sdk-10-version-2004-windbg
