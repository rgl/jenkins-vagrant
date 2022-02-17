# install the plugins.
vagrant plugin install vagrant-reload
vagrant plugin install vagrant-execute
vagrant plugin install vagrant-scp
vagrant plugin install vagrant-windows-sysprep
vagrant plugin install vagrant-vsphere
vagrant plugin install vagrant-vmware-esxi

# create dummy vsphere boxes.
Set-Content -Encoding Ascii -Path metadata.json -Value '{"provider":"vsphere"}'
tar czf vsphere_dummy.box metadata.json
vagrant box add windows-2022-amd64 vsphere_dummy.box
vagrant box add windows-10-amd64 vsphere_dummy.box
Remove-Item vsphere_dummy.box,metadata.json

# list them.
vagrant plugin list
vagrant box list
