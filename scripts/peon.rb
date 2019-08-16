class Peon
  def Peon.work(config, settings)
    scripts_home = File.dirname(__FILE__)
    instances = settings["instances"]

    instances.each do |instance|
      count = instance["count"]
      (1..count).each do |i|
        config.vm.define "#{instance["name"]}-#{i}"
        config.vm.hostname = "#{instance["name"]}-#{i}"
        instance_settings = instance["settings"]
        config.vm.box = instance_settings["box"]
        config.vm.box_check_update = true
        config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
        config.ssh.forward_agent = true

        config.vm.provider "virtualbox" do |vb|
          config.vbguest.auto_update = true

          vb.customize ["modifyvm", :id, "--memory", instance_settings["memory"] ||= "1024"]
          vb.customize ["modifyvm", :id, "--cpus", instance_settings["cpus"] ||= "1"]
          config.disksize.size = instance_settings["disk_size"] ||= "20GB"

          if instance_settings.include? "network"
            network_settings = instance_settings["network"]
            private_network_ip = network_settings["private_network_ip"].split(".")
            ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.#{private_network_ip[2]}.#{private_network_ip[3].to_i + i}"
            config.vm.network :private_network, ip: ip
          end      

          vb.name = "#{instance["name"]}-#{i}"
          vb.linked_clone = true
          vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
          vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
          vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]      
        end

        config.vm.provision "shell" do |s|
          s.name = "Install Ansible"
          s.path = scripts_home + "/ansible-install.sh"
          s.args = "2.6.1"
        end

        config.vm.provision "shell" do |s|
          s.name = "Execute Ansible Playbook"
          s.inline = "ansible-playbook /vagrant/ansible/playbook.yml -i \"localhost,\" -c local"        
        end
      end
    end    
  end
end