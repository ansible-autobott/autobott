#!/bin/bash
# TODO: adjust for the chosen Debian 14 (forky) base box.
# If the box already bundles VirtualBox Guest Additions (like bento/debian-13),
# this cleanup-only script is enough; otherwise port the guest-additions
# install steps from an older bake-base script.
echo "clean"
apt-get autoremove
apt-get autoclean
