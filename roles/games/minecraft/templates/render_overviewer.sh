#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

{% if minecraft_config.overviewer.cron.stop_minecraft  %}
# stop minecraft
echo "stopping minecraft"
systemctl stop minecraft.service
{% endif %}

# run renderer as user
su {{ minecraft_config.user.name }} -s /bin/bash -c \
 '/usr/bin/flock -n /tmp/minecraft_overviewer_render.lockfile \
  minecraft-overviewer -c {{ minecraft_config.paths.base }}/overviewer/overviewer.cfg.py'

su {{ minecraft_config.user.name }} -s /bin/bash -c \
 '/usr/bin/flock -n /tmp/minecraft_overviewer_render.lockfile \
  minecraft-overviewer -c {{ minecraft_config.paths.base }}/overviewer/overviewer.cfg.py --genpoi'

{% if minecraft_config.overviewer.cron.stop_minecraft %}
# start minecraft
echo "starting minecraft"
systemctl start minecraft.service
{% endif %}

