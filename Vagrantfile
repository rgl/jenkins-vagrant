# to make sure the jenkins node is created before the other nodes, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

config_jenkins_fqdn = 'jenkins.example.com'
config_jenkins_ip   = '10.10.10.100'
config_ubuntu_fqdn  = "ubuntu.#{config_jenkins_fqdn}"
config_ubuntu_ip    = '10.10.10.101'
config_windows_fqdn = "windows.#{config_jenkins_fqdn}"
config_windows_ip   = '10.10.10.102'
config_macos_fqdn   = "macos.#{config_jenkins_fqdn}"
config_macos_ip     = '10.10.10.103'

# link to the gitlab-vagrant environment.
config_gitlab_fqdn  = 'gitlab.example.com'
config_gitlab_ip    = '10.10.9.99'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-24.04-uefi-amd64'

  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2048
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    # lv.nested = true
    lv.keymap = 'pt'
    lv.random :model => 'random'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs', nfs_version: '4.2', nfs_udp: false
  end

  config.vm.define :jenkins do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.machine_virtual_size = 32 # GB
    end
    config.vm.hostname = config_jenkins_fqdn
    config.vm.network :private_network, ip: config_jenkins_ip, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "echo '#{config_ubuntu_ip} #{config_ubuntu_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_windows_ip} #{config_windows_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_macos_ip} #{config_macos_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-resize-disk.sh'
    config.vm.provision :shell, path: 'provision-certificates.sh'
    config.vm.provision :shell, path: 'provision-mailpit.sh'
    config.vm.provision :shell, path: 'provision.sh'
    config.vm.provision :shell, path: 'provision-example-jobs.sh'
    config.vm.provision :shell, path: 'provision-example-test-jenkins-gitlab-plugin.sh'
    config.vm.provision :reload
    config.vm.provision :shell, path: 'provision-summary.sh'
  end

  config.vm.define :ubuntu do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.machine_virtual_size = 64 # GB
    end
    config.vm.hostname = config_ubuntu_fqdn
    config.vm.network :private_network, ip: config_ubuntu_ip, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "echo '#{config_jenkins_ip} #{config_jenkins_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-resize-disk.sh'
    config.vm.provision :shell, path: 'provision-ubuntu.sh'
    config.vm.provision :shell, path: 'provision-docker.sh'
    config.vm.provision :shell, path: 'provision-docker-compose.sh'
  end

  config.vm.define :windows do |config|
    config.vm.provider :libvirt do |lv, config|
      lv.memory = 4096
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end
    config.vm.box = 'windows-2022-uefi-amd64'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: config_windows_ip, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "echo '#{config_jenkins_ip} #{config_jenkins_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-chocolatey.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-containers-feature.ps1'
    config.vm.provision :shell, inline: "echo 'Rebooting...'", reboot: true
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-base.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-docker-ce.ps1', config_windows_fqdn]
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-compose.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-docker-reg.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-vs-build-tools.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-dotnet-sdk.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-msys2.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-vagrant.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-enable-long-paths.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: 'provision-procdump.ps1'
    config.vm.provision :shell, path: 'windows/ps.ps1', args: ['provision-jenkins-agent.ps1', config_jenkins_fqdn, config_windows_fqdn]
  end

  config.vm.define :macos do |config|
    config.vm.box = 'macOS'
    config.vm.hostname = config_macos_fqdn
    config.vm.network :private_network, ip: config_macos_ip, libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "echo '#{config_jenkins_ip} #{config_jenkins_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_gitlab_ip} #{config_gitlab_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-macos.sh', privileged: false
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'jenkins'
    trigger.run = {
      inline: '''bash -euc \'
certs=(
  ../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der
  ../gitlab-vagrant/tmp/gitlab.example.com-crt.der
  ../gitlab-vagrant/tmp/gitlab-jenkins-impersonation-token.txt
)
for cert_path in "${certs[@]}"; do
  if [ -f $cert_path ]; then
    mkdir -p tmp
    cp $cert_path tmp
  fi
done
\'
'''
    }
  end

  config.trigger.before :up do |trigger|
    trigger.only_on = 'macos'
    trigger.run = {inline: "echo 'You first need to download Xcode_8.1.xip from https://developer.apple.com/download/more/'; exit 1"} unless File.file?('Xcode_8.1.xip') || File.file?('Xcode_8.1.cpio.xz')
  end

  config.trigger.after :up do |trigger|
    trigger.only_on = 'macos'
    trigger.run = {inline: "sh -c \"vagrant ssh -c 'cat /vagrant/tmp/#{config_macos_fqdn}.ssh_known_hosts' macos >tmp/#{config_macos_fqdn}.ssh_known_hosts\""}
    trigger.run = {inline: "sh -c \"vagrant ssh -c 'cat /vagrant/Xcode_8.1.cpio.xz' macos >Xcode_8.1.cpio.xz.tmp && mv Xcode_8.1.cpio.xz{.tmp,}\""} unless File.file? 'Xcode_8.1.cpio.xz'
    trigger.run = {inline: "sh -c \"vagrant ssh -c 'cat /vagrant/Xcode_8.1.cpio.xz.shasum' macos >Xcode_8.1.cpio.xz.shasum.tmp && mv Xcode_8.1.cpio.xz.shasum{.tmp,}\""} unless File.file? 'Xcode_8.1.cpio.xz.shasum'
  end

  config.trigger.after :up do |trigger|
    trigger.only_on = ['ubuntu', 'macos']
    trigger.run = {inline: "vagrant ssh -c 'cat /vagrant/tmp/*.ssh_known_hosts | sudo tee /etc/ssh/ssh_known_hosts' jenkins"}
  end
end
