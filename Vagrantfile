# -*- mode: ruby -*-
# vi: set ft=ruby :
hostname = "k8master.local"
# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  config.vm.define "k8" do |k8|
    k8.vm.box = "centos/7"
    k8.vm.host_name = hostname
    k8.vm.network "private_network", ip: "192.168.33.121"
    k8.vm.synced_folder ".", "/vagrant", disabled: true
    k8.vm.provider "virtualbox" do |v|
      v.memory = 4096
    end
   k8.vm.provision "shell", path: "kube-bootstrap.sh", args: hostname
  end
end
