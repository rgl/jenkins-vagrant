param(
    [Parameter(Mandatory=$true)]
    [string]$config_jenkins_master_fqdn = 'jenkins.example.com',

    [Parameter(Mandatory=$true)]
    [string]$config_fqdn = 'windows.jenkins.example.com'
)

# install git and related applications.
choco install -y git --params '/GitOnlyOnPath /NoAutoCrlf /SChannel'
choco install -y gitextensions
choco install -y meld

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

# configure git.
# see http://stackoverflow.com/a/12492094/477532
git config --global user.name 'Rui Lopes'
git config --global user.email 'rgl@ruilopes.com'
git config --global http.sslbackend schannel
git config --global push.default simple
git config --global core.autocrlf false
git config --global diff.guitool meld
git config --global difftool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global difftool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$REMOTE\"'
git config --global merge.tool meld
git config --global mergetool.meld.path 'C:/Program Files (x86)/Meld/Meld.exe'
git config --global mergetool.meld.cmd '\"C:/Program Files (x86)/Meld/Meld.exe\" \"$LOCAL\" \"$BASE\" \"$REMOTE\" --auto-merge --output \"$MERGED\"'
#git config --list --show-origin

# install testing tools.
choco install -y xunit
choco install -y reportgenerator.portable
# NB we need to install a recent (non-released) version due
#    to https://github.com/OpenCover/opencover/issues/736
Push-Location opencover-rgl.portable
choco pack
choco install -y opencover-rgl.portable -Source $PWD
Pop-Location

# install troubeshooting tools.
choco install -y procexp
choco install -y procmon

# add start menu entries.
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Explorer.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procexp\tools\procexp64.exe'
Install-ChocolateyShortcut `
    -ShortcutFilePath 'C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Process Monitor.lnk' `
    -TargetPath 'C:\ProgramData\chocolatey\lib\procmon\tools\procmon.exe'

# import the Jenkins master site https certificate into the local machine trust store.
Import-Certificate `
    -FilePath C:/vagrant/tmp/$config_jenkins_master_fqdn-crt.der `
    -CertStoreLocation Cert:/LocalMachine/Root

# import the gitlab-vagrant environment site https certificate into the local machine trust store.
if (Test-Path C:/vagrant/tmp/gitlab.example.com-crt.der) {
    Import-Certificate `
        -FilePath C:/vagrant/tmp/gitlab.example.com-crt.der `
        -CertStoreLocation Cert:/LocalMachine/Root
}

# install the JRE.
choco install -y server-jre8
Update-SessionEnvironment
Write-Output 'Enabling the unlimited JCE policy...'
$jceInstallPath = "$env:JAVA_HOME\jre\lib\security"
Copy-Item "$jceInstallPath\policy\unlimited\*.jar" $jceInstallPath

# restart the SSH service so it can re-read the environment (e.g. the system environment
# variables like PATH) after we have installed all this slave node dependencies.
Restart-Service sshd

# create the jenkins user account and home directory.
[Reflection.Assembly]::LoadWithPartialName('System.Web') | Out-Null
$jenkinsAccountName = 'jenkins'
$jenkinsAccountPassword = [Web.Security.Membership]::GeneratePassword(32, 8)
$jenkinsAccountPasswordSecureString = ConvertTo-SecureString $jenkinsAccountPassword -AsPlainText -Force
$jenkinsAccountCredential = New-Object `
    Management.Automation.PSCredential `
    -ArgumentList `
        $jenkinsAccountName,
        $jenkinsAccountPasswordSecureString
New-LocalUser `
    -Name $jenkinsAccountName `
    -FullName 'Jenkins Slave' `
    -Password $jenkinsAccountPasswordSecureString `
    -PasswordNeverExpires
# login to force the system to create the home directory.
# NB the home directory will have the correct permissions, only the
#    SYSTEM, Administrators and the jenkins account are granted full
#    permissions to it.
Start-Process -WindowStyle Hidden -Credential $jenkinsAccountCredential -WorkingDirectory 'C:\' -FilePath cmd -ArgumentList '/c'

# configure the account to allow ssh connections from the jenkins master.
mkdir C:\Users\$jenkinsAccountName\.ssh | Out-Null
copy C:\vagrant\tmp\$config_jenkins_master_fqdn-ssh-rsa.pub C:\Users\$jenkinsAccountName\.ssh\authorized_keys

# configure the jenkins home.
choco install -y pstools
Copy-Item C:\vagrant\windows\configure-jenkins-home.ps1 C:\tmp
psexec `
    -accepteula `
    -nobanner `
    -u $jenkinsAccountName `
    -p $jenkinsAccountPassword `
    -h `
    PowerShell -File C:\tmp\configure-jenkins-home.ps1
Remove-Item C:\tmp\configure-jenkins-home.ps1

# create the storage directory hierarchy.
# grant the SYSTEM, Administrators and $jenkinsAccountName accounts
# Full Permissions to the c:\j directory and children.
$jenkinsDirectory = mkdir c:\j
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
mkdir $jenkinsDirectory\lib | Out-Null
Invoke-WebRequest "https://$config_jenkins_master_fqdn/jnlpJars/slave.jar" -OutFile $jenkinsDirectory\lib\slave.jar

# create artifacts that need to be shared with the other nodes.
mkdir -Force C:\vagrant\tmp | Out-Null
[IO.File]::WriteAllText(
    "C:\vagrant\tmp\$config_fqdn.ssh_known_hosts",
    (dir 'C:\ProgramData\ssh\ssh_host_*_key.pub' | %{ "$config_fqdn $(Get-Content $_)`n" }) -join ''
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
function Write-Title($title) {
    Write-Host "`n#`n# $title`n"
}
Write-Title 'Installed DotNet version'
Write-Host (Get-DotNetVersion)
Write-Title 'Installed MSBuild version'
MSBuild -version
Write-Title 'Installed chocolatey packages'
choco list -l
