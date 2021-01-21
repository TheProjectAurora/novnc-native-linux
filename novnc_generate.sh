#!/bin/sh
set -xe

echo "******************************************"
echo "INFO: Hello from $0"
echo "******************************************"

#SOURCE TO WHOLE PROCEDURE: https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc/dockerfile
### https://hub.docker.com/r/dorowu/ubuntu-desktop-lxde-vnc
### https://github.com/fcwu/docker-ubuntu-vnc-desktop


################################################################################
# base system
###############################################################################

export DEBIAN_FRONTEND=noninteractive
apt update \
    && apt install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        supervisor nginx sudo net-tools zenity xz-utils \
        dbus-x11 x11-utils alsa-utils \
        mesa-utils libgl1-mesa-dri \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

#By default NGINX is on????
systemctl stop nginx
systemctl disable nginx
#By default supervisord is on????
systemctl stop supervisor.service
systemctl disable supervisor.service
# WITHOUT THIS: https://stackoverflow.com/questions/25121838/supervisor-on-debian-wheezy-another-program-is-already-listening-on-a-port-that
# unlink /var/run/supervisor.sock

# install debs error if combine together
apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        xvfb x11vnc \
        vim-tiny firefox ttf-ubuntu-font-family ttf-wqy-zenhei  \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

apt update \
    && apt install -y gpg-agent \
    && curl -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && (dpkg -i ./google-chrome-stable_current_amd64.deb || apt-get install -fy) \
    && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add \
    && rm google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        lxde gtk2-engines-murrine gnome-themes-standard gtk2-engines-pixbuf gtk2-engines-murrine arc-theme \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# tini to fix subreap
export TINI_VERSION=v0.18.0
wget https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini
mv -f tini /bin/tini
chmod +x /bin/tini

# ffmpeg
apt update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /usr/local/ffmpeg \
    && ln -s /usr/bin/ffmpeg /usr/local/ffmpeg/ffmpeg

# python library
cp /docker-ubuntu-vnc-desktop/rootfs/usr/local/lib/web/backend/requirements.txt /tmp/
apt-get update \
    && dpkg-query -W -f='${Package}\n' > /tmp/a.txt \
    && apt-get install -y python3-pip python3-dev build-essential \
	&& pip3 install setuptools wheel && pip3 install -r /tmp/requirements.txt \
    && ln -s /usr/bin/python3 /usr/local/bin/python \
    && dpkg-query -W -f='${Package}\n' > /tmp/b.txt \
    && apt-get remove -y `diff --changed-group-format='%>' --unchanged-group-format='' /tmp/a.txt /tmp/b.txt | xargs` \
    && apt-get autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* /tmp/a.txt /tmp/b.txt

################################################################################
# builder This should be dockerized => Check more idea from Dockerfile_build_vagrant
###############################################################################
#sed -i 's#http://archive.ubuntu.com/ubuntu/#mirror://mirrors.ubuntu.com/mirrors.txt#' /etc/apt/sources.list;

apt update \
    && apt install -y --no-install-recommends curl ca-certificates gnupg patch

# nodejs
curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && echo all > /etc/gcrypt/hwf.deny \
    && apt update \
    && apt install -y nodejs

# yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && echo all > /etc/gcrypt/hwf.deny \
    && apt update \
    && apt install -y yarn

# build frontend
cd /docker-ubuntu-vnc-desktop/web \
    && yarn \
    && yarn build
sed -i 's#app/locale/#novnc/app/locale/#' /docker-ubuntu-vnc-desktop/web/dist/static/novnc/app/ui.js

################################################################################
# merge
###############################################################################
mkdir -p /usr/local/lib/web/frontend/
cp -R /docker-ubuntu-vnc-desktop/web/dist/* /usr/local/lib/web/frontend/
cp -R /docker-ubuntu-vnc-desktop/rootfs/* /
ln -sf /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify && \
	chmod +x /usr/local/lib/web/frontend/static/websockify/run

export HOME=/home/ubuntu \
       SHELL=/bin/bash
chmod +x /startup.sh
sed -i "s|\(.*supervisord.*\)-n\(.*\)|\1 \2|g" /startup.sh

# root@ubuntu-focal:~# cat /etc/systemd/system/novnc.service
tee /etc/systemd/system/novnc.service << END
[Unit]
Description=supervisord - Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
#EnvironmentFile=/etc/my_service/my_service.conf
#Environment="FOO=bar"
Type=forking
ExecStart=/startup.sh
ExecReload=/usr/bin/supervisorctl reload
ExecStop=/usr/bin/supervisorctl shutdown
KillMode=process
Restart=on-failure
RestartSec=50s

[Install]
WantedBy=multi-user.target
END

###
####Start up coommands:
systemctl daemon-reload
systemctl enable novnc.service
systemctl start novnc.service
#STATUS:
# root@ubuntu-focal:~# systemctl status novnc.service
# ● novnc.service - supervisord - Supervisor process control system for UNIX
#      Loaded: loaded (/etc/systemd/system/novnc.service; enabled; vendor preset: enabled)
#      Active: active (running) since Wed 2021-01-20 14:13:16 UTC; 5min ago
#        Docs: http://supervisord.org
#     Process: 39968 ExecStart=/startup.sh (code=exited, status=0/SUCCESS)
#    Main PID: 39973 (supervisord)
#       Tasks: 28 (limit: 4682)
#      Memory: 187.0M
#      CGroup: /system.slice/novnc.service
#              ├─39973 /usr/bin/python3 /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
#              ├─39978 nginx: master process nginx -c /etc/nginx/nginx.conf -g daemon off;
#              ├─39979 python3 /usr/local/lib/web/backend/run.py
#              ├─39985 nginx: worker process
#              ├─40019 /usr/lib/menu-cache/menu-cached /root/.cache/menu-cached-:1
#              ├─40041 /usr/bin/Xvfb :1 -screen 0 1716x1259x24
#              ├─40042 /usr/bin/openbox
#              ├─40043 /usr/bin/lxpanel --profile LXDE
#              ├─40044 /usr/bin/pcmanfm --desktop --profile LXDE
#              ├─40045 x11vnc -display :1 -xkb -forever -shared -repeat -capslock
#              ├─40046 bash /usr/local/lib/web/frontend/static/novnc/utils/launch.sh --listen 6081
#              └─40067 python /usr/local/lib/web/frontend/static/novnc/utils/websockify/run --web /usr/local/lib/web/frontend/static/novnc 6081 localhost:5900
# 
# Jan 20 14:13:16 ubuntu-focal systemd[1]: Starting supervisord - Supervisor process control system for UNIX...
# Jan 20 14:13:16 ubuntu-focal startup.sh[39968]: [WARN  tini (39968)] Tini is not running as PID 1 and isn't registered as a child subreaper.
# Jan 20 14:13:16 ubuntu-focal startup.sh[39968]: Zombie processes will not be re-parented to Tini, so zombie reaping won't work.
# Jan 20 14:13:16 ubuntu-focal startup.sh[39968]: To fix the problem, use the -s option or set the environment variable TINI_SUBREAPER to register Tini as a child subreaper, or run Tini as PID 1.
# Jan 20 14:13:16 ubuntu-focal systemd[1]: Started supervisord - Supervisor process control system for UNIX.

### KILL: 
# systemctl stop novnc.service
## MANUAL KILL:
# kill -9 `echo $(ps aux | egrep -i "nginx|vnc|supervisord|Xvfb|openbox|lxpanel|pcmanfm" | grep -v grep | awk '{print $2}')`
# kill -9 `echo $(lsof -i -P -n | egrep "nginx|python|vnc" | awk '{print $2}')`

### NOTE: Just require more ENV variables than normal systemctl shell offer
#Define those to: novnc.service 
#EnvironmentFile=/etc/my_service/my_service.conf
#Environment="FOO=bar"