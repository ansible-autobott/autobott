#!/bin/bash
echo "install Virtualbox Guest Additions"

sudo apt-get update && sudo apt-get -y install dkms build-essential wget


echo "download and install guest additions"
# https://download.virtualbox.org/virtualbox
wget -q https://download.virtualbox.org/virtualbox/7.0.10/VBoxGuestAdditions_7.0.10.iso
sudo mkdir /mnt/cdrom
sudo mount -o loop /home/vagrant/VBoxGuestAdditions_7.0.10.iso /mnt/cdrom
cd /mnt/cdrom || exit 1

sudo sh ./VBoxLinuxAdditions.run --nox11 || true

cd /
umount /mnt/cdrom
rm /home/vagrant/VBoxGuestAdditions_7.0.10.iso

echo "clean"
apt-get autoremove
apt-get autoclean