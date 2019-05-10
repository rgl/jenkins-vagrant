# install packer and plugins.
choco install -y packer packer-provisioner-windows-update

# install vagrant plugins.
# NB plugins are installed at the current user profile, as such, we install them
#    here and on the jenkins account from configure-jenkins-home.ps1.
choco install -y vagrant

# install govc.
choco install -y govc

# update $env:PATH with the recently installed Chocolatey packages.
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1"
Update-SessionEnvironment

# install vagrant plugins.
. .\provision-vagrant-plugins.ps1
