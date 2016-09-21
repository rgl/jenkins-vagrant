config_jenkins_fqdn = 'jenkins.example.com'
config_jenkins_ip   = '10.10.10.100'
config_ubuntu_fqdn  = "ubuntu.#{config_jenkins_fqdn}"
config_ubuntu_ip    = '10.10.10.101'
config_windows_fqdn = "windows.#{config_jenkins_fqdn}"
config_windows_ip   = '10.10.10.102'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-16.04-amd64'

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.define :jenkins do |config|
    config.vm.hostname = config_jenkins_fqdn
    config.vm.network :private_network, ip: config_jenkins_ip
    config.vm.provision :shell, inline: "echo '#{config_ubuntu_ip} #{config_ubuntu_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, inline: "echo '#{config_windows_ip} #{config_windows_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision.sh'
  end

  config.vm.define :ubuntu do |config|
    config.vm.hostname = config_ubuntu_fqdn
    config.vm.network :private_network, ip: config_ubuntu_ip
    config.vm.provision :shell, inline: "echo '#{config_jenkins_ip} #{config_jenkins_fqdn}' >>/etc/hosts"
    config.vm.provision :shell, path: 'provision-ubuntu.sh'
  end

  config.vm.define :windows do |config|
    config.vm.box = 'windows_2012_r2'
    config.vm.hostname = 'windows'
    config.vm.network :private_network, ip: config_windows_ip
    config.vm.provision :shell, inline: "echo '#{config_jenkins_ip} #{config_jenkins_fqdn}' | Out-File -Encoding ASCII -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, inline: "$env:chocolateyVersion='0.10.0'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision :shell, path: 'provision-windows.ps1', args: [config_jenkins_fqdn, config_windows_fqdn]
  end

  config.trigger.after :up, :vm => ['ubuntu', 'windows'] do
    run "vagrant ssh -c 'cat /vagrant/tmp/*.ssh_known_hosts | sudo tee /etc/ssh/ssh_known_hosts' jenkins"
  end
end
