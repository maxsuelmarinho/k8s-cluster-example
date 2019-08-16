#!/usr/bin/env bash

. /etc/init.d/functions

echo "===================================="
echo "Installing Ansible"
echo "===================================="

ANSIBLE_VERSION=$1

if [ "$(ansible --version 2>&1 | awk '/ansible [0-9\.]/{print $2}' | egrep -o '[^\"]*')" == "${ANSIBLE_VERSION}" ]; then
  echo "Ansible already installed. Skiping..."
  success
  exit 0
fi

sudo yum install -y python python-setuptools.noarch
sudo easy_install pip
sudo pip install "ansible==${ANSIBLE_VERSION}"

command -v ansible > /dev/null 2>&1 || {
    echo
    echo 'Error! Ansible is not installed!'
    failure
    echo
    exit 1
}

echo "Ansible installed."
success
echo
exit 0
