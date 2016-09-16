Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu-16.04-amd64'

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
  end

  config.vm.define :jenkins do |config|
    config.vm.hostname = 'jenkins.example.com'
    config.vm.network :private_network, ip: '10.10.10.100'
    config.vm.provision :shell, path: 'provision.sh'
  end
end