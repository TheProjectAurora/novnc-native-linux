#!/bin/sh
set -xe
mv -fv /home/vagrant/novnc-native-linux /
chown -Rv root:root /novnc-native-linux
chmod -Rv 600 /novnc-native-linux
chmod -v +x /novnc-native-linux/novnc_install.sh
/novnc-native-linux/novnc_install.sh