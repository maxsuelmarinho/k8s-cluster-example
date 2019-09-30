class Peon
  def Peon.work(config, settings)
    scripts_home = File.dirname(__FILE__)
    instances = settings["instances"]

    master_settings = instances.select { |item| item["type"] == "master" }
    worker_settings = instances.select { |item| item["type"] == "worker" }
    
    master_settings.each_with_index do |instance, index|
      count = instance["count"]
      (1..count).each do |i|
        
        instance_name = "#{instance["name"]}-#{i}"
        master_node_ip = ""
        node_ip = ""
        config.vm.define instance_name, primary: instance["type"] == "master" do |node|
          node.vm.hostname = instance_name
          instance_settings = instance["settings"]
          node.vm.box = instance_settings["box"]
          node.vm.box_check_update = instance_settings["box_check_update"] ||= true
          node.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
          node.ssh.forward_agent = true

          network_settings = instance_settings["network"]
          node.vm.provider "virtualbox" do |vb|
            required_plugins = %w(vagrant-vbguest vagrant-disksize vagrant-share vagrant-sshfs)
            required_plugins.each do |plugin|
              unless Vagrant.has_plugin? plugin
                  system "vagrant plugin install #{plugin}"
                  _retry=true
              end
            end
            node.vbguest.auto_update = instance_settings["vbguest_auto_update"] ||= true
            # disk re-size does not work on WSL
            #node.disksize.size = instance_settings["disk_size"] ||= "20GB"
            private_network_ip = network_settings["private_network_ip"].split(".")
            node_ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.#{private_network_ip[2]}.#{private_network_ip[3].to_i + i}"
                        
            node.vm.network :private_network, ip: node_ip

            vb.name = instance_name
            vb.linked_clone = true
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]      
            vb.customize ["modifyvm", :id, "--memory", instance_settings["memory"] ||= "1024"]
            vb.customize ["modifyvm", :id, "--cpus", instance_settings["cpus"] ||= "1"]
          end

          node.vm.provision :ansible do |ansible|
            ansible.playbook = "ansible/playbook.yml"
            ansible.extra_vars = {
              "apiserver_advertise_address" => node_ip,
              "pod_network_cidr" => network_settings["pod_network_cidr"],
              "node_ip" => node_ip
            }
          end
        end
      end
    end

    worker_settings.each_with_index do |instance, index|
      count = instance["count"]
      (1..count).each do |i|
        
        instance_name = "#{instance["name"]}-#{i}"
        node_ip = ""
        config.vm.define instance_name, primary: instance["type"] == "master" do |node|
          node.vm.hostname = instance_name
          instance_settings = instance["settings"]
          node.vm.box = instance_settings["box"]
          node.vm.box_check_update = instance_settings["box_check_update"] ||= true
          node.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
          node.ssh.forward_agent = true

          network_settings = instance_settings["network"]          
          node.vm.provider "virtualbox" do |vb|
            required_plugins = %w(vagrant-vbguest vagrant-disksize vagrant-share vagrant-sshfs)
            required_plugins.each do |plugin|
              unless Vagrant.has_plugin? plugin
                  system "vagrant plugin install #{plugin}"
                  _retry=true
              end
            end
            node.vbguest.auto_update = instance_settings["vbguest_auto_update"] ||= true
            # disk re-size does not work on WSL
            #node.disksize.size = instance_settings["disk_size"] ||= "20GB"
            private_network_ip = network_settings["private_network_ip"].split(".")
            node_ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.#{private_network_ip[2]}.#{private_network_ip[3].to_i + i}"
            
            if instance["type"] == "master" then
              master_node_ip = node_ip
            end
            
            node.vm.network :private_network, ip: node_ip

            vb.name = instance_name
            vb.linked_clone = true
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]      
            vb.customize ["modifyvm", :id, "--memory", instance_settings["memory"] ||= "1024"]
            vb.customize ["modifyvm", :id, "--cpus", instance_settings["cpus"] ||= "1"]
          end
          
          node.vm.provision :ansible do |ansible|
            ansible.playbook = "ansible/playbook.yml"
            ansible.extra_vars = {
              "node_ip" => node_ip
            }
          end
        end
      end     
    end
  end
end