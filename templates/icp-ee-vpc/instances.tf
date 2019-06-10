data "ibm_is_image" "osimage" {
  name = "${var.os_image}"
}

data "ibm_is_instance_profile" "icp-boot-profile" {
  name = "${var.boot["profile"]}"
}

data "ibm_is_instance_profile" "icp-master-profile" {
  name = "${var.master["profile"]}"
}

data "ibm_is_instance_profile" "icp-proxy-profile" {
  name = "${var.proxy["profile"]}"
}

data "ibm_is_instance_profile" "icp-worker-profile" {
  name = "${var.worker["profile"]}"
}

data "ibm_is_instance_profile" "icp-mgmt-profile" {
  name = "${var.mgmt["profile"]}"
}

data "ibm_is_instance_profile" "icp-va-profile" {
  name = "${var.va["profile"]}"
}

resource "ibm_is_floating_ip" "icp-boot-pub" {
  name 	 = "${var.deployment}-boot-${random_id.clusterid.hex}-pubip"
  target = "${ibm_is_instance.icp-boot.primary_network_interface.0.id}"
}

##############################################
## Provision boot node
##############################################
#resource "ibm_is_volume" "icp-boot-vol" {
#  name = "${var.deployment}-boot-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.boot["disk_size"]}"
#}
#
#resource "ibm_is_volume" "icp-boot-docker-vol" {
#  name = "${var.deployment}-boot-docker-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.boot["docker_vol_size"]}"
#}

resource "ibm_is_instance" "icp-boot" {
  name = "${var.deployment}-boot-${random_id.clusterid.hex}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, 0)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-boot-profile.name}"

  primary_network_interface = {
    port_speed = "${var.boot["network_speed"]}"
    subnet = "${element(ibm_is_subnet.icp_subnet.*.id, 0)}"
    security_groups = ["${list(ibm_is_security_group.boot_node.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${ibm_is_volume.icp-boot-vol.id}",
#    "${ibm_is_volume.icp-boot-docker-vol.id}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF
}

#resource "ibm_is_volume" "icp-master-vol" {
#  count    = "${var.master["nodes"]}"
#  name = "${var.deployment}-master-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.master["disk_size"]}"
#}
#
#resource "ibm_is_volume" "icp-master-docker-vol" {
#  count    = "${var.master["nodes"]}"
#  name     = "${format("%s-master-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
#  profile  = "general-purpose"
#  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.master["docker_vol_size"]}"
#}

resource "ibm_is_instance" "icp-master" {
  count = "${var.master["nodes"]}"
  name  = "${format("%s-master%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-master-profile.name}"

  primary_network_interface = {
    port_speed = "${var.master["network_speed"]}"
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.master_node.id, 
                               ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${element(ibm_is_volume.icp-master-vol.*.id, count.index)}",
#    "${element(ibm_is_volume.icp-master-docker-vol.*.id, count.index)}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

  provisioner "file" {
    # copy the local docker installation package if it's set
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    source = "${var.docker_package_location != "" ? "${var.docker_package_location}" : "${path.module}/icp-install/README.md"}"
    destination = "${local.docker_package_uri != "" ? "${local.docker_package_uri}" : "/dev/null" }"
  }

  # wait until cloud-init finishes
  provisioner "remote-exec" {
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }
}

#resource "ibm_is_volume" "icp-mgmt-vol" {
#  count    = "${var.mgmt["nodes"]}"
#  name = "${var.deployment}-mgmt-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.mgmt["disk_size"]}"
#}
#
#resource "ibm_is_volume" "icp-mgmt-docker-vol" {
#  count    = "${var.mgmt["nodes"]}"
#  name     = "${format("%s-mgmt-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
#  profile  = "general-purpose"
#  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.mgmt["docker_vol_size"]}"
#}

resource "ibm_is_instance" "icp-mgmt" {
  count = "${var.mgmt["nodes"]}"
  name  = "${format("%s-mgmt%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-mgmt-profile.name}"

  primary_network_interface = {
    port_speed = "${var.mgmt["network_speed"]}"
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${element(ibm_is_volume.icp-mgmt-vol.*.id, count.index)}",
#    "${element(ibm_is_volume.icp-mgmt-docker-vol.*.id, count.index)}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF
  provisioner "file" {
    # copy the local docker installation package if it's set
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    source = "${var.docker_package_location != "" ? "${var.docker_package_location}" : "${path.module}/icp-install/README.md"}"
    destination = "${local.docker_package_uri != "" ? "${local.docker_package_uri}" : "/dev/null" }"
  }

  # wait until cloud-init finishes
  provisioner "remote-exec" {
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }
}

#resource "ibm_is_volume" "icp-worker-vol" {
#  count    = "${var.worker["nodes"]}"
#  name = "${var.deployment}-worker-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.worker["disk_size"]}"
#}
#
#resource "ibm_is_volume" "icp-worker-docker-vol" {
#  count    = "${var.worker["nodes"]}"
#  name     = "${format("%s-worker-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
#  profile  = "general-purpose"
#  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.worker["docker_vol_size"]}"
#}

resource "ibm_is_instance" "icp-worker" {
  count = "${var.worker["nodes"]}"
  name  = "${format("%s-worker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-worker-profile.name}"

  primary_network_interface = {
    port_speed = "${var.worker["network_speed"]}"
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${element(ibm_is_volume.icp-worker-vol.*.id, count.index)}",
#    "${element(ibm_is_volume.icp-worker-docker-vol.*.id, count.index)}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

  provisioner "file" {
    # copy the local docker installation package if it's set
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    source = "${var.docker_package_location != "" ? "${var.docker_package_location}" : "${path.module}/icp-install/README.md"}"
    destination = "${local.docker_package_uri != "" ? "${local.docker_package_uri}" : "/dev/null" }"
  }

  # wait until cloud-init finishes
  provisioner "remote-exec" {
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }
}

resource "ibm_is_instance" "icp-proxy" {
  count = "${var.proxy["nodes"]}"
  name  = "${format("%s-proxy%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-proxy-profile.name}"

  primary_network_interface = {
    port_speed = "${var.proxy["network_speed"]}"
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.proxy_node.id, 
                               ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${element(ibm_is_volume.icp-proxy-vol.*.id, count.index)}",
#    "${element(ibm_is_volume.icp-proxy-docker-vol.*.id, count.index)}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

  provisioner "file" {
    # copy the local docker installation package if it's set
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    source = "${var.docker_package_location != "" ? "${var.docker_package_location}" : "${path.module}/icp-install/README.md"}"
    destination = "${local.docker_package_uri != "" ? "${local.docker_package_uri}" : "/dev/null" }"
  }

  # wait until cloud-init finishes
  provisioner "remote-exec" {
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }
}
#resource "ibm_is_volume" "icp-va-vol" {
#  count    = "${var.va["nodes"]}"
#  name = "${var.deployment}-va-${random_id.clusterid.hex}"
#  profile = "general-purpose"
#  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.va["disk_size"]}"
#}
#
#resource "ibm_is_volume" "icp-va-docker-vol" {
#  count    = "${var.va["nodes"]}"
#  name     = "${format("%s-va-docker%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"
#  profile  = "general-purpose"
#  zone     = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"
#  capacity = "${var.va["docker_vol_size"]}"
#}



resource "ibm_is_instance" "icp-va" {
  count = "${var.va["nodes"]}"
  name  = "${format("%s-va%02d-%s", var.deployment, count.index + 1, random_id.clusterid.hex)}"

  vpc  = "${ibm_is_vpc.icp_vpc.id}"
  zone = "${element(data.ibm_is_zone.icp_zone.*.name, count.index)}"

  keys = ["${data.ibm_is_ssh_key.public_key.*.id}"]
  profile = "${data.ibm_is_instance_profile.icp-va-profile.name}"

  primary_network_interface = {
    port_speed = "${var.va["network_speed"]}"
    subnet     = "${element(ibm_is_subnet.icp_subnet.*.id, count.index)}"
    security_groups = ["${list(ibm_is_security_group.cluster_private.id)}"]
  }

  image   = "${data.ibm_is_image.osimage.id}"
#  volumes = [
#    "${element(ibm_is_volume.icp-va-vol.*.id, count.index)}",
#    "${element(ibm_is_volume.icp-va-docker-vol.*.id, count.index)}"
#  ]

  user_data = <<EOF
#cloud-config
packages:
- unzip
- python
- pv
- nfs-common
users:
- default
- name: icpdeploy
  groups: [ wheel ]
  sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
  shell: /bin/bash
  ssh-authorized-keys:
  - ${tls_private_key.installkey.public_key_openssh}
write_files:
- path: /opt/ibm/scripts/bootstrap.sh
  permissions: '0755'
  encoding: b64
  content: ${base64encode(file("${path.module}/scripts/bootstrap.sh"))}
runcmd:
- /opt/ibm/scripts/bootstrap.sh -u icpdeploy ${local.docker_package_uri != "" ? "-p ${local.docker_package_uri}" : "" }
EOF

  provisioner "file" {
    # copy the local docker installation package if it's set
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    source = "${var.docker_package_location != "" ? "${var.docker_package_location}" : "${path.module}/icp-install/README.md"}"
    destination = "${local.docker_package_uri != "" ? "${local.docker_package_uri}" : "/dev/null" }"
  }

  # wait until cloud-init finishes
  provisioner "remote-exec" {
    connection {
      host          = "${self.primary_network_interface.0.primary_ipv4_address}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${ibm_is_floating_ip.icp-boot-pub.address}"
    }

    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done"
    ]
  }

}