# Purpose:
NoVNC offers a full X-windows experience that is usable over browser. This repository could be used as "bootstrap" to virtual machine when GUI is required. 

# Requirements:
- Ubuntu 20.04
- 443 port open to VM

# USAGE:
1. Clone repo to VM in bootstrap
1. Execute `novnc_install.sh` in bootstrap

BEHAVIOR:
* Install required tools to host
* Open with browser to https://IP <= user:**coder** pw: **coderpw** (defined in novnc_environment.conf )
* NoVNC session opened to browser and offer full linux desktop
* Left bottom corner of noVNC desktop is arrow where open main menu of linux desctop
>**FYI**: Google Chrome eats a lot of cpu&mem so Firefox browser is recomended to be used.

# MODIFY SETTING (resolution, PW, etc.):
NOTE. If you want to change username then it should be done in many places. So it is recommendation to use 
1. Edit novnc_environment.conf file
1. Reboot VM (with reboot novnc systemd daemon is loaded pefectry, restart of daemon could work ok)

# Known problems (Existing features):
* Copy-Paste between noVNC<->HOST happens by using noVNC desctop left side menu (click arrow in center of noVNC window) and open clipboard by using it icon in menu. This is a textbox where you should paste your copy from HOST and then it could be pasted to noVNC side. Copying from noVNC to HOST happens by using same method but vice versa way.
* CapsLock could seem to be out of sync between noVNC desktop and HOST. That's why change CapsLock status always in HOST side window (e.g. by using host browser url row)

# SECURITY:
1. Only 443 port should be opened to host
1. nginx behind of 443 port handle SSL termination
1. only basic auth is in use
1. Public connection to host have to be limited by using cloud provider tools (it is recommended that just your IP or subnet could take connection to host)
1. There is no guarantee of security of 3rd party SW like noVNC

# TESTING:
1. Kickup: `vagrant up`
1. Check USAGE how to use
1. Destroy: `vagrant destroy`
<<<<<<< HEAD

# ADDONS
## Vagrant startup:
Require tools: https://www.vagrantup.com/ https://www.virtualbox.org/
1. Start: `vagrant up`
1. Test as in BEHAVIOR in https://github.com/TheProjectAurora/novnc-native-linux#usage 
1. Delete: `vagrant destroy`

## Create&Test Vagrant BOX
Require same tools than 
Box creation happened with: https://www.packer.io/
1. Execute: `packer build novnc.pkr.hcl`
1. Create folder and go there: `mkdir owbox && cd ownbox`
1. Import BOX: `vagrant box add novnc ../output-novnc/package.box`
1. Init vagrant: `vagrant init novnc`
1. Add 443=>443 port forwarding to Vagrantfile by editing it and adding folowing line:
```config.vm.network "forwarded_port", guest: 443, host: 443```
1. Start vagrant: `vagrant up`
1. Test as in BEHAVIOR in https://github.com/TheProjectAurora/novnc-native-linux#usage
1. Delete: `vagrant destroy`
1. Delete packer stuff: `cd .. && rm -Rf output-novnc owbox`
=======
>>>>>>> 453573d537db35447677ee2260ae324e88e2a311
