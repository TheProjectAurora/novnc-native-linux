source "vagrant" "novnc" {
  communicator = "ssh"
  source_path = "ubuntu/focal64"
  provider = "virtualbox"
  add_force = true
  box_name = "novnc"
}

build {
  sources = ["source.vagrant.novnc"]

  provisioner "shell" {
    inline = ["mkdir -pv /home/vagrant/novnc-native-linux"]
  }

  provisioner "file" {
    destination = "/home/vagrant/novnc-native-linux/"
    sources     = [ "Dockerfile_novnc_node_web",
                    "./novnc_environment.conf", 
                    "./novnc_install.sh", 
                    "./novnc_openssl.cnf", 
                    "./novnc.service", 
                    "./Vagrantfile_bootstrap.sh"]
  }
  provisioner "shell" {
    inline =  [ "sudo chown -v root:root /home/vagrant/novnc-native-linux/Vagrantfile_bootstrap.sh",
                "sudo chmod -v +x /home/vagrant/novnc-native-linux/Vagrantfile_bootstrap.sh",
                "sudo /home/vagrant/novnc-native-linux/Vagrantfile_bootstrap.sh" ]
  }
}