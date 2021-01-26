#!/bin/sh
set -xe

echo "INFO: bootstrap.sh that is named to $0 script from `hostname`"
echo "I am: `whoami`"
echo "My location is:`pwd`"

# HACK: Hash sum mismatch when apt-get update Ubuntu 20.04 VM with Multipass
# Source: https://stackoverflow.com/questions/64120030/hash-sum-mismatch-when-apt-get-update-ubuntu-20-04-vm-with-multipass
mkdir -p /etc/gcrypt
echo all > /etc/gcrypt/hwf.deny

  #&& apt dist-upgrade -y  
  #
apt-get -qq -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update \
  && apt install -qq --no-install-recommends --allow-unauthenticated -y \
  git \
  socat \
  docker.io \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

#HACK TO GET GIT working: https://wiki.yoctoproject.org/wiki/Working_Behind_a_Network_Proxy
#Require also "socat" in apt install ^
wget -q http://git.yoctoproject.org/cgit/cgit.cgi/poky/plain/scripts/oe-git-proxy -P /bin
chmod +x /bin/oe-git-proxy
export GIT_PROXY_COMMAND="oe-git-proxy"
export NO_PROXY=""

#CLONE NoVNC REPO WITH CHACK => Same problem with virtualbox BOXees: ubuntu/focal64 , generic/debian9 , generic/fedora30
cd /
n=0
until [ $n -ge 5 ]
do
   rm -Rf docker-ubuntu-vnc-desktop
   git clone -b develop --recursive https://github.com/fcwu/docker-ubuntu-vnc-desktop.git && break
   echo "WARNING: CLONE FAIL - RETRY CLONE"
   n=$[$n+1]
   sleep 1
done
# IF STILL CONTINUE FAILING => CHECK GOOGLE SEARCH: git clone fail "virtualbox"
cd -
chmod +x /home/vagrant/novnc_generate.sh
/home/vagrant/novnc_generate.sh