#!/bin/bash
set -e

# clean before starting
vagrant box remove --force autobott-debian-12-base || true
vagrant destroy -f


# intall some plugins
vagrant plugin install vagrant-disksize

# start the vagrant machine and install guest additions
vagrant up

# package a box and install it locally
vagrant package
vagrant box add autobott-debian-12-base ./package.box

# clean after done
rm package.box
vagrant destroy -f

