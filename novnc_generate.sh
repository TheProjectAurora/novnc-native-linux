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
apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
    && apt install -y --no-install-recommends software-properties-common curl apache2-utils \
    && apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
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
apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        xvfb x11vnc \
        vim-tiny firefox ttf-ubuntu-font-family ttf-wqy-zenhei  \
    && apt autoclean -y \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
    && apt install -y gpg-agent \
    && curl -LO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && (dpkg -i ./google-chrome-stable_current_amd64.deb || apt-get install -fy) \
    && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add \
    && rm google-chrome-stable_current_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
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
apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
    && apt install -y --no-install-recommends --allow-unauthenticated \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /usr/local/ffmpeg \
    && ln -s /usr/bin/ffmpeg /usr/local/ffmpeg/ffmpeg

# python library
cp /docker-ubuntu-vnc-desktop/rootfs/usr/local/lib/web/backend/requirements.txt /tmp/
apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
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
# node builder 
###############################################################################
mv Dockerfile_novnc_node_web /docker-ubuntu-vnc-desktop/Dockerfile_novnc_node_web
cd /docker-ubuntu-vnc-desktop
docker build -t novnc_node_web -f Dockerfile_novnc_node_web .
cd -
################################################################################
# merge
###############################################################################
mkdir -p /usr/local/lib/web/frontend/
docker run --rm -v /usr/local/lib/web/frontend/:/frontend novnc_node_web
docker image rm novnc_node_web

cp -R /docker-ubuntu-vnc-desktop/rootfs/* /
ln -sf /usr/local/lib/web/frontend/static/websockify /usr/local/lib/web/frontend/static/novnc/utils/websockify && \
	chmod +x /usr/local/lib/web/frontend/static/websockify/run

export HOME=/home/ubuntu \
       SHELL=/bin/bash
chmod +x /startup.sh
sed -i "s|\(.*supervisord.*\)-n\(.*\)|\1 \2|g" /startup.sh

# generate self signed ssl:
mkdir -p /etc/nginx/ssl/
tee /etc/nginx/ssl/openssl.cnf << EOF1
[ req ]
prompt = no
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C = GB
ST = Test State
L = Test Locality
O = Org Name
OU = Org Unit Name
CN = Common Name
emailAddress = test@email.com
EOF1
openssl req -x509 -config /etc/nginx/ssl/openssl.cnf -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt

#create user:
mkdir /home/coder
adduser --gecos '' --disabled-password coder
usermod -a -G sudo coder
chown -R coder:coder /home/coder
# Set password and other coder user things are handled with noVNC environment
tee /etc/systemd/novnc_environment.conf << EOF2
SSL_PORT=443
USER=coder
PASSWORD=coderpw
HOME=/home/coder
HTTP_PASSWORD=coderpw
#RESOLUTION=1920x1080
#X11VNC_ARGS=-multiptr
EOF2
# root@ubuntu-focal:~# cat /etc/systemd/system/novnc.service
tee /etc/systemd/system/novnc.service << END
[Unit]
Description=supervisord - Supervisor process control system for UNIX
Documentation=http://supervisord.org
After=network.target

[Service]
#User=coder
EnvironmentFile=/etc/systemd/novnc_environment.conf
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