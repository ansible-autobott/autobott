#!/bin/bash
# VirtualBox Guest Additions are already bundled in the boxomatic/debian-13 box.
# This script only runs cleanup.
echo "clean"
apt-get autoremove
apt-get autoclean
