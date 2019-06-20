resource "ibm_is_security_group" "cluster_private" {
  name = "${var.deployment}-cluster-priv-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_rule" "allow_ingress_from_self_priv" {
  direction = "ingress"
  remote = "${ibm_is_security_group.cluster_private.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
}

resource "ibm_is_security_group_rule" "allow_ssh_ingress_from_boot_priv" {
  direction = "ingress"
  remote = "${ibm_is_security_group.boot_node.id}"
  group = "${ibm_is_security_group.cluster_private.id}"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "allow_cluster_egress_private" {
  direction = "egress"
  group = "${ibm_is_security_group.cluster_private.id}"
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "master_node" {
  name = "${var.deployment}-master-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_network_interface_attachment" "master" {
  count = "${var.master["nodes"]}"
  security_group    = "${ibm_is_security_group.master_node.id}"
  network_interface = "${element(ibm_is_instance.icp-master.*.primary_network_interface.0.id, count.index)}"
}

# restrict incoming on ports to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_8443" {
  direction = "ingress"
  tcp {
    port_min = 8443
    port_max = 8443
  }
  group = "${ibm_is_security_group.master_node.id}"
  #remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_8500" {
  direction = "ingress"
  tcp {
    port_min = 8500
    port_max = 8500
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_8600" {
  direction = "ingress"
  tcp {
    port_min = 8600
    port_max = 8600
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# TODO restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_8001" {
  direction = "ingress"
  tcp {
    port_min = 8001
    port_max = 8001
  } 
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}


# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_9443" {
  direction = "ingress"
  tcp {
    port_min = 9443
    port_max = 9443
  }
  group = "${ibm_is_security_group.master_node.id}"
  # remote = "${ibm_compute_vm_instance.icp-master.0.private_subnet}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_80" {
  direction = "ingress"
  tcp {
    port_min = 80
    port_max = 80
  }
  group = "${ibm_is_security_group.proxy_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

# restrict to LBaaS private subnet
resource "ibm_is_security_group_rule" "allow_port_443" {
  direction = "ingress"
  tcp {
    port_min = 443
    port_max = 443
  }
  group = "${ibm_is_security_group.proxy_node.id}"
  # Sometimes LBaaS can be placed on a different subnet
  remote = "0.0.0.0/0"
}

resource "ibm_is_security_group" "proxy_node" {
  name = "${var.deployment}-proxy-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_network_interface_attachment" "proxy" {
  count = "${var.proxy["nodes"] > 0 ? var.proxy["nodes"] : var.master["nodes"]}"
  security_group    = "${ibm_is_security_group.proxy_node.id}"
  network_interface = "${var.proxy["nodes"] > 0 ? 
    element(ibm_is_instance.icp-proxy.*.primary_network_interface.0.id, count.index) :
    element(ibm_is_instance.icp-master.*.primary_network_interface.0.id, count.index)}"
}

resource "ibm_is_security_group" "boot_node" {
  name = "${var.deployment}-boot-${random_id.clusterid.hex}"
  vpc = "${ibm_is_vpc.icp_vpc.id}"
}

resource "ibm_is_security_group_network_interface_attachment" "boot" {
  security_group    = "${ibm_is_security_group.boot_node.id}"
  network_interface = "${ibm_is_instance.icp-boot.primary_network_interface.0.id}"
}

# TODO restrict to allowed CIDR
resource "ibm_is_security_group_rule" "allow_inbound_ssh" {
  group = "${ibm_is_security_group.boot_node.id}"
  direction = "ingress"
  remote = "0.0.0.0/0"
  tcp {
    port_min = 22
    port_max = 22
  }
}

resource "ibm_is_security_group_rule" "allow_egress" {
  group = "${ibm_is_security_group.boot_node.id}"
  remote = "0.0.0.0/0"
  direction = "egress"
}
