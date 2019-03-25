resource "ibm_lbaas" "proxy-lbaas" {
  name = "${var.deployment}-proxy-${random_id.clusterid.hex}"
  description = "load balancer for ICP proxy"

  subnets = ["${element(concat(ibm_compute_vm_instance.icp-proxy.*.private_subnet_id,
                             ibm_compute_vm_instance.icp-master.*.private_subnet_id),
                0)}"]
  protocols = [
    {
      frontend_protocol = "TCP"
      frontend_port = 443

      backend_protocol = "TCP"
      backend_port = 443
    },
    {
      frontend_protocol = "TCP"
      frontend_port = 80

      backend_protocol = "TCP"
      backend_port = 80
    }
  ]
}

resource "ibm_lbaas_server_instance_attachment" "icp_proxy" {
  count = "${var.proxy["nodes"] > 0 ? var.proxy["nodes"] : var.master["nodes"]}"
  private_ip_address = "${element(concat(ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private, ibm_compute_vm_instance.icp-master.*.ipv4_address_private), count.index)}"
  lbaas_id = "${ibm_lbaas.proxy-lbaas.id}"
}

resource "ibm_lbaas" "master-lbaas" {
  name = "${var.deployment}-mastr-${random_id.clusterid.hex}"
  description = "load balancer for ICP master"

  subnets = ["${ibm_compute_vm_instance.icp-master.0.private_subnet_id}"]
  protocols = [
    {
      frontend_protocol = "TCP"
      frontend_port = 8443

      backend_protocol = "TCP"
      backend_port = 8443
    },
    {
      frontend_protocol = "TCP"
      frontend_port = 8001

      backend_protocol = "TCP"
      backend_port = 8001
    },
    {
      frontend_protocol = "TCP"
      frontend_port = 8500

      backend_protocol = "TCP"
      backend_port = 8500
    },
    {
      frontend_protocol = "TCP"
      frontend_port = 8600

      backend_protocol = "TCP"
      backend_port = 8600
    },
    {
      frontend_protocol = "TCP"
      frontend_port = 9443

      backend_protocol = "TCP"
      backend_port = 9443
    }
  ]
}



resource "ibm_lbaas_server_instance_attachment" "icp_master" {
  count = "${var.master["nodes"]}"
  private_ip_address = "${element(ibm_compute_vm_instance.icp-master.*.ipv4_address_private, count.index)}"
  lbaas_id = "${ibm_lbaas.master-lbaas.id}"
}
