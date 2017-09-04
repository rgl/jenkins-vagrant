param(
    [Parameter(Mandatory=$true)]
    [string]$config_jenkins_master_fqdn = 'jenkins.example.com',

    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.jenkins.example.com'
)

# install git and related applications.
choco install -y git --params '/GitOnlyOnPath /NoAutoCrlf'
choco install -y gitextensions
choco install -y meld

# install xUnit.
choco install -y xunit

# install troubeshooting tools.
choco install -y procexp
choco install -y procmon

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Update-SessionEnvironment

# add start menu entries.
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Explorer.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procexp\tools\procexp64.exe'
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Monitor.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procmon\tools\procmon.exe'

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global push.default simple
git config --global core.autocrlf false
git config --global diff.guitool meld
git config --global difftool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global difftool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$REMOTE\"'
git config --global merge.tool meld
git config --global mergetool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global mergetool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$BASE\" \"$REMOTE\" --auto-merge --output \"$MERGED\"'
#git config --list --show-origin

# import the Jenkins master site https certificate into the local machine trust store.
Import-Certificate `
    -FilePath C:/vagrant/tmp/$config_jenkins_master_fqdn-crt.der `
    -CertStoreLocation Cert:/LocalMachine/Root

# install the JRE.
choco install -y jre8 -PackageParameters '/exclude:32'
# TODO install JCE too.

# restart the SSH service so it can re-read the environment (e.g. the system environment
# variables like PATH) after we have installed all this slave node dependencies.
Restart-Service OpenSSHd

# create the jenkins user account and home directory.
[Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null
$jenkinsAccountName = 'jenkins'
$jenkinsAccountPassword = [Web.Security.Membership]::GeneratePassword(32, 8)
$jenkinsAccountCredential = New-Object `
    Management.Automation.PSCredential `
    -ArgumentList `
        $jenkinsAccountName,
        (ConvertTo-SecureString $jenkinsAccountPassword -AsPlainText -Force)
net user $jenkinsAccountName $jenkinsAccountPassword /add /y /fullname:"Jenkins Slave" | Out-Null
wmic useraccount where "name='$jenkinsAccountName'" set PasswordExpires=FALSE | Out-Null
# login to force the system to create the home directory.
# NB the home directory will have the correct permissions, only the
#    SYSTEM, Administrators and the jenkins account are granted full
#    permissions to it.
Start-Process cmd /c -WindowStyle Hidden -Credential $jenkinsAccountCredential
mkdir C:\Users\$jenkinsAccountName\.ssh | Out-Null
copy C:\vagrant\tmp\$config_jenkins_master_fqdn-ssh-rsa.pub C:\Users\$jenkinsAccountName\.ssh\authorized_keys

# create the storage directory hierarchy.
# grant the SYSTEM, Administrators and $jenkinsAccountName accounts
# Full Permissions to the C:\jenkins directory and children.
$jenkinsDirectory = mkdir C:\jenkins
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
@(
    'SYSTEM'
    'Administrators'
    $jenkinsAccountName
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
$jenkinsDirectory.SetAccessControl($acl)

# download the slave jar and install it.
mkdir C:\jenkins\lib | Out-Null
Invoke-WebRequest "https://$config_jenkins_master_fqdn/jnlpJars/slave.jar" -OutFile C:\jenkins\lib\slave.jar
mkdir C:\jenkins\bin | Out-Null
[IO.File]::WriteAllText(
    'C:\jenkins\bin\jenkins-slave',
    @"
#!/bin/sh
#set
exec java -jar c:/jenkins/lib/slave.jar
"@)

# create artifacts that need to be shared with the other nodes.
mkdir -Force C:\vagrant\tmp | Out-Null
[IO.File]::WriteAllText(
    "C:\vagrant\tmp\$config_fqdn.ssh_known_hosts",
    (dir 'C:\Program Files\OpenSSH\etc\ssh_host_*_key.pub' | %{ "$config_fqdn $(Get-Content $_)`n" }) -join ''
)

# add default desktop shortcuts (called from a provision-base.ps1 generated script).
[IO.File]::WriteAllText(
    "$env:USERPROFILE\ConfigureDesktop-Jenkins.ps1",
@'
[IO.File]::WriteAllText(
    "$env:USERPROFILE\Desktop\Jenkins Master.url",
    @"
[InternetShortcut]
URL=https://{0}
"@)
'@ -f $config_jenkins_master_fqdn)

# show installation summary.
Write-Host 'Installed DotNet version:'
Write-Host (Get-DotNetVersion)
Write-Host 'Installed chocolatey packages:'
choco list -l
