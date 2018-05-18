resource "ibm_security_group" "cluster_group" {
  name = "${var.deployment}-cluster-security-group"
  description = "allow intercluster communication"
}

resource "ibm_security_group_rule" "allow_ingress_from_self" {
  direction = "ingress"
  ether_type = "IPv4"
  remote_group_id = "${ibm_security_group.cluster_group.id}"
  security_group_id = "${ibm_security_group.cluster_group.id}"
}

resource "ibm_security_group_rule" "allow_all_cluster_egress" {
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.cluster_group.id}"
}

resource "ibm_security_group" "master_group" {
  name = "${var.deployment}-master-security-group"
  description = "allow incoming to master"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8443
  port_range_max = 8443
  security_group_id = "${ibm_security_group.master_group.id}"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8500" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8500
  port_range_max = 8500
  security_group_id = "${ibm_security_group.master_group.id}"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_8001" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 8001
  port_range_max = 8001
  security_group_id = "${ibm_security_group.master_group.id}"
}


# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_9443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 9443
  port_range_max = 9443
  security_group_id = "${ibm_security_group.master_group.id}"
}

resource "ibm_security_group_rule" "master_node_allow_outbound_public" {
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.master_group.id}"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_80" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 80
  port_range_max = 80
  security_group_id = "${ibm_security_group.proxy_group.id}"
}

# TODO restrict to LBaaS private subnet
resource "ibm_security_group_rule" "allow_port_443" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 443
  port_range_max = 443
  security_group_id = "${ibm_security_group.proxy_group.id}"
}

resource "ibm_security_group" "proxy_group" {
  name = "${var.deployment}-proxy-security-group"
  description = "allow incoming to proxy"
}

resource "ibm_security_group" "boot_node_public" {
  name = "${var.deployment}-boot-nodes-public"
  description = "allow incoming ssh"
}

# TODO restrict to allowed CIDR
resource "ibm_security_group_rule" "allow_ssh" {
  direction = "ingress"
  ether_type = "IPv4"
  protocol = "tcp"
  port_range_min = 22
  port_range_max = 22
  security_group_id = "${ibm_security_group.boot_node_public.id}"
}

resource "ibm_security_group_rule" "boot_node_allow_outbound_public" {
  direction = "egress"
  ether_type = "IPv4"
  security_group_id = "${ibm_security_group.boot_node_public.id}"
}
