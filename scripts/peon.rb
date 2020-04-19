class Peon
  def Peon.work(config, settings)
    scripts_home = File.dirname(__FILE__)
    instances = settings["instances"]

    master_settings = instances.find { |item| item["type"] == "master" }
    worker_settings = instances.find { |item| item["type"] == "worker" }
    
    masters = (1..master_settings["count"]).each.map { |i| "#{master_settings["name"]}-#{i}" }
    workers = (1..worker_settings["count"]).each.map { |i| "#{worker_settings["name"]}-#{i}" }
    ansible_groups = { "masters" => masters, "workers" => workers }
    ansible_host_vars = {}

    pod_network_cidr = master_settings["settings"]["network"]["pod_network_cidr"] ||= ""
    cgroup_driver = master_settings["settings"]["cgroup_driver"]
    if pod_network_cidr.empty? then
      abort "'pod_network_cidr' is required for instance type 'master'."
    end

    master_node_ip = ""
    cert_extra_sans = ""
    node_ip = ""

    instances.each_with_index do |instance, index|
      count = instance["count"]
      (1..count).each do |i|
        
        instance_name = "#{instance["name"]}-#{i}"
        config.vm.define instance_name, primary: instance["type"] == "master" do |node|
          node.vm.hostname = instance_name
          instance_settings = instance["settings"]
          node.vm.box = instance_settings["box"]
          node.vm.box_version = instance_settings["box_version"] ||= "1804.02"
          node.vm.box_check_update = instance_settings["box_check_update"] ||= true
          node.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
          node.ssh.forward_agent = true

          network_settings = instance_settings["network"]
          private_network_ip = network_settings["private_network_ip"].split(".")
          node_ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.#{private_network_ip[2]}.#{private_network_ip[3].to_i + i}"
          public_node_ip = "#{private_network_ip[0]}.#{private_network_ip[1]}.0.#{private_network_ip[3].to_i + i}"
          
          node.vm.network :private_network, ip: node_ip
          node.vm.network :public_network, ip: public_node_ip
          
          node.vm.provision "shell" do |s|
            s.name = "Prevent problem with vbguest and shared folders"
            s.inline = <<-SHELL
            sudo yum update -y \
              && sudo yum -y install kernel-devel kernel-headers dkms gcc gcc-c++ \
              && sudo yum -y update kernel
            SHELL
          end

          # Standardize Ports Naming Schema
          if network_settings.include? "ports"
            network_settings["ports"].each do |port|
              port["guest"] ||= port["to"]
              port["host"] ||= port["send"]
              port["protocol"] ||= "tcp"
            end
          else
            network_settings["ports"] = []
          end
          
          # Add Custom Ports From Configuration
          if network_settings.include? "ports"
            network_settings["ports"].each do |port|
              config.vm.network "forwarded_port", guest: port["guest"], host: port["host"], protocol: port["protocol"], auto_correct: true
            end
          end
          
          instance_host_vars = {
            instance_name => {
              "ansible_host" => node_ip,
              "ansible_ssh_private_key_file" => "/vagrant/.vagrant/machines/#{instance_name}/virtualbox/private_key",
              "node_ip" => node_ip,
              "cgroup_driver" => cgroup_driver 
            }
          }

          if instance["type"] == "master" then
            if network_settings.include? "cert_extra_sans"
              cert_extra_sans = "#{public_node_ip},#{node_ip},#{network_settings["cert_extra_sans"]}"
            else
              cert_extra_sans = "#{public_node_ip},#{node_ip}"
            end
            
            instance_host_vars[instance_name]["cert_extra_sans"] = cert_extra_sans
            instance_host_vars[instance_name]["apiserver_advertise_address"] = public_node_ip
            instance_host_vars[instance_name]["pod_network_cidr"] = pod_network_cidr
          end

          ansible_host_vars.merge!(instance_host_vars)

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

            vb.name = instance_name
            vb.linked_clone = true
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]      
            vb.customize ["modifyvm", :id, "--memory", instance_settings["memory"] ||= "1024"]
            vb.customize ["modifyvm", :id, "--cpus", instance_settings["cpus"] ||= "1"]
          end

          #config.vm.provision "shell" do |s|
          #  s.name = "DNS config"
          #  s.path = scripts_home + "/dns-config.sh"
          #end

          #node.vm.provision "shell" do |s|
          #  s.name = "Install Ansible"
          #  s.path = scripts_home + "/ansible-install.sh"
          #  s.args = "2.6.1"
          #end

          #node.vm.provision "shell" do |s|
          #  s.name = "Execute Ansible Playbook"
          #  s.inline = "ansible-playbook /vagrant/ansible/playbook.yml -i \"localhost,\" -c local --extra-vars \"node_type=#{instance["type"]} apiserver_advertise_address=#{node_ip} pod_network_cidr=#{pod_network_cidr}\""
          #end
        end
      end     
    end

    # ansible provisioner
    provisioner_machine_name = "provisioner-machine"
    config.vm.define provisioner_machine_name do |provisioner|
      provisioner.vm.box = master_settings["settings"]["box"]
      provisioner.vm.box_version = master_settings["settings"]["box_version"]
      provisioner.vm.box_check_update = master_settings["settings"]["box_check_update"]
      provisioner.vm.hostname = provisioner_machine_name
      provisioner.vm.network "private_network", ip: "192.168.33.110"
      provisioner.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"
      provisioner.ssh.forward_agent = true

      provisioner.vm.provision "shell" do |s|
        s.name = "Prevent problem with vbguest and shared folders"
        s.inline = <<-SHELL
        sudo yum update -y \
          && sudo yum -y install kernel-devel kernel-headers dkms gcc gcc-c++ \
          && sudo yum -y update kernel
        SHELL
      end

      provisioner.vm.provider "virtualbox" do |vb|
        vb.name = provisioner_machine_name
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
        vb.customize ["modifyvm", :id, "--memory", "1024"]
        vb.customize ["modifyvm", :id, "--cpus", master_settings["settings"]["cpus"]]

        required_plugins = %w(vagrant-vbguest vagrant-disksize vagrant-share vagrant-sshfs)
        required_plugins.each do |plugin|
          unless Vagrant.has_plugin? plugin
              system "vagrant plugin install #{plugin}"
              _retry=true
          end
        end
        provisioner.vbguest.auto_update = true
      end

      config.vm.synced_folder ".", "/vagrant", type: "virtualbox", owner: "vagrant", mount_options: ["dmode=775,fmode=600"]

      provisioner.vm.provision "ansible_local" do |ansible|
        # disable default limit to connect to all the machines
        ansible.limit = "all"
        ansible.playbook = "ansible/playbook.yml"
        ansible.config_file = 'ansible/ansible.cfg'
        ansible.verbose = true # true, "vvv", or "vvvv"
        ansible.groups = ansible_groups
        ansible.host_vars = ansible_host_vars
      end
    end
  end
end