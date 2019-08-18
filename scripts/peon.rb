class Peon
  def Peon.work(config, settings)
    scripts_home = File.dirname(__FILE__)
    instances = settings["instances"]

    instances.each do |instance|
      count = instance["count"]
      (1..count).each do |i|
        
        config.vm.define "#{instance["name"]}-#{i}" do |node|
          node.vm.hostname = "#{instance["name"]}-#{i}"
          instance_settings = instance["settings"]
          node.vm.box = instance_settings["box"]
          node.vm.box_check_update = instance_settings["box_check_update"] ||= true
          node.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
          node.ssh.forward_agent = true

          network_settings = instance_settings["network"]
          node_ip = ""
          pod_network_cidr = network_settings["pod_network_cidr"] ||= ""
          if instance["type"] == "master" && pod_network_cidr.empty? then
            abort "'pod_network_cidr' is required for instance type 'master'."
          end
          node.vm.provider "virtualbox" do |vb|
            node.vbguest.auto_update = instance_settings["vbguest_auto_update"] ||= true
            node.disksize.size = instance_settings["disk_size"] ||= "20GB"
            private_network_ip = network_settings["private_network_ip"].split(".")
            node_ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.#{private_network_ip[2]}.#{private_network_ip[3].to_i + i}"
            node.vm.network :private_network, ip: node_ip

            vb.name = "#{instance["name"]}-#{i}"
            vb.linked_clone = true
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]      
            vb.customize ["modifyvm", :id, "--memory", instance_settings["memory"] ||= "1024"]
            vb.customize ["modifyvm", :id, "--cpus", instance_settings["cpus"] ||= "1"]
          end

          node.vm.provision "shell" do |s|
            s.name = "Install Ansible"
            s.path = scripts_home + "/ansible-install.sh"
            s.args = "2.6.1"
          end

          node.vm.provision "shell" do |s|
            s.name = "Execute Ansible Playbook"
            s.inline = "ansible-playbook /vagrant/ansible/playbook.yml -i \"localhost,\" -c local --extra-vars \"node_type=#{instance["type"]} apiserver_advertise_address=#{node_ip} pod_network_cidr=#{pod_network_cidr}\""
          end
        end
      end
    end    
  end
end