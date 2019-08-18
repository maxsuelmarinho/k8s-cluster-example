# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Vagrantfile API/syntax version.
VAGRANTFILE_API_VERSION ||= "2"

ENV['VAGRANT_DEFAULT_PROVIDER'] = "virtualbox"

Vagrant.require_version '>= 1.9.0'

require File.expand_path(File.dirname(__FILE__) + '/scripts/peon.rb')
confDir = $confDir ||= File.expand_path(File.dirname(__FILE__))
settingsPath = confDir + "/settings.yml"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if File.exist? settingsPath then
    settings = YAML::load(File.read(settingsPath))
  else
    abort "'settings.yml' file not found in #{confDir}."
  end

  Peon.work(config, settings)  
end