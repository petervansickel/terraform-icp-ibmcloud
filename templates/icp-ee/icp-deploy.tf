##########################################
### Load the ICP Enterprise images tarball
## This is skipped if installing from
## external private registry
##########################################
resource "null_resource" "image_copy" {
  # Only copy image from local location if not available remotely
  count = "${var.image_location != "" ? 1 : 0}"

  provisioner "file" {
    connection {
      host          = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
      user          = "icpdeploy"
      private_key   = "${tls_private_key.installkey.private_key_pem}"
      bastion_host  = "${var.private_network_only ? ibm_compute_vm_instance.icp-boot.ipv4_address_private : ibm_compute_vm_instance.icp-boot.ipv4_address}"
    }

    source = "${var.image_location}"
    destination = "/tmp/${basename(var.image_location)}"
  }
}

resource "null_resource" "image_load" {
  # Only do an image load if we have provided a location. Presumably if not we'll be loading from private registry server
  depends_on = ["null_resource.image_copy"]

  connection {
    host          = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
    user          = "icpdeploy"
    private_key   = "${tls_private_key.installkey.private_key_pem}"
    bastion_host  = "${var.private_network_only ? ibm_compute_vm_instance.icp-boot.ipv4_address_private : ibm_compute_vm_instance.icp-boot.ipv4_address}"
  }

  provisioner "file" {
    source = "${path.module}/scripts/load_image.sh"
    destination = "/tmp/load_image.sh"
  }

  provisioner "remote-exec" {

    # We need to wait for cloud init to finish it's boot sequence.
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "export REGISTRY_USERNAME=${local.docker_username}",
      "export REGISTRY_PASSWORD=${local.docker_password}",
      "sudo mv /tmp/load_image.sh /opt/ibm/scripts/",
      "sudo chmod a+x /opt/ibm/scripts/load_image.sh",
      "/opt/ibm/scripts/load_image.sh ${var.image_location != "" ? "-p ${var.image_location}" : ""} -r ${local.registry_server} -c ${local.docker_password}",
      "sudo touch /opt/ibm/.imageload_complete"
    ]
  }
}

resource "null_resource" "cert_copy" {
  # copy the CA certs, if they exist
  depends_on = ["null_resource.image_load"]

  connection {
    host          = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
    user          = "icpdeploy"
    private_key   = "${tls_private_key.installkey.private_key_pem}"
    bastion_host  = "${var.private_network_only ? ibm_compute_vm_instance.icp-boot.ipv4_address_private : ibm_compute_vm_instance.icp-boot.ipv4_address}"
  }

  provisioner "remote-exec" {
    # We need to wait for cloud init to finish it's boot sequence.
    inline = [
      "mkdir -p /tmp/cfc-certs"
    ]
  }

  provisioner "file" {
    source = "${path.module}/cfc-certs/"
    destination = "/tmp/cfc-certs"
  }

  provisioner "remote-exec" {
    # We need to wait for cloud init to finish it's boot sequence.
    inline = [
      "sudo mkdir -p /opt/ibm/cluster",
      "sudo mv /tmp/cfc-certs /opt/ibm/cluster"
    ]
  }

}

##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.3.5"

    # Provide IP addresses for boot, master, mgmt, va, proxy and workers
    boot-node = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
    bastion_host  = "${var.private_network_only ? ibm_compute_vm_instance.icp-boot.ipv4_address_private : ibm_compute_vm_instance.icp-boot.ipv4_address}"
    icp-host-groups = {
        master = ["${ibm_compute_vm_instance.icp-master.*.ipv4_address_private}"]
        proxy = "${slice(concat(ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private,
                                ibm_compute_vm_instance.icp-master.*.ipv4_address_private),
                         var.proxy["nodes"] > 0 ? 0 : length(ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private),
                         var.proxy["nodes"] > 0 ? length(ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private) :
                                                  length(ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private) +
                                                    length(ibm_compute_vm_instance.icp-master.*.ipv4_address_private))}"

        worker = ["${ibm_compute_vm_instance.icp-worker.*.ipv4_address_private}"]

        // make the master nodes managements nodes if we don't have any specified
        management = "${slice(concat(ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private,
                                     ibm_compute_vm_instance.icp-master.*.ipv4_address_private),
                              var.mgmt["nodes"] > 0 ? 0 : length(ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private),
                              var.mgmt["nodes"] > 0 ? length(ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private) :
                                                      length(ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private) +
                                                        length(ibm_compute_vm_instance.icp-master.*.ipv4_address_private))}"

        va = ["${ibm_compute_vm_instance.icp-va.*.ipv4_address_private}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${local.icp-version}"

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${1 + var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.mgmt["nodes"] + var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_3.1.0/installing/config_yaml.html
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_lb_address"              = "${ibm_lbaas.master-lbaas.vip}"
      "proxy_lb_address"                = "${ibm_lbaas.proxy-lbaas.vip}"
      "cluster_CA_domain"               = "${var.cluster_cname != "" ? "${var.cluster_cname}" : "${ibm_lbaas.master-lbaas.vip}"}"
      "cluster_name"                    = "${var.deployment}"
      "calico_ip_autodetection_method"  = "interface=eth0"

      # An admin password will be generated if not supplied in terraform.tfvars
      "default_admin_password"          = "${local.icppassword}"

      # This is the list of disabled management services
      "management_services"             = "${local.disabled_management_services}"

      "private_registry_enabled"        = "${var.registry_server != "" ? "true" : "false" }"
      "private_registry_server"         = "${local.registry_server}"
      "image_repo"                      = "${local.image_repo}" # Will either be our private repo or external repo
      "docker_username"                 = "${local.docker_username}" # Will either be username generated by us or supplied by user
      "docker_password"                 = "${local.docker_password}" # Will either be username generated by us or supplied by user
    }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "icpdeploy"
    ssh_key_base64  = "${base64encode(tls_private_key.installkey.private_key_pem)}"
    ssh_agent       = false

    # Make sure to wait for image load to complete
    hooks = {
      "boot-preconfig" = [
        "while [ ! -f /opt/ibm/.imageload_complete ]; do sleep 5; done"
      ]
    }

    ## Alternative approach
    # hooks = {
    #   "cluster-preconfig" = ["echo No hook"]
    #   "cluster-postconfig" = ["echo No hook"]
    #   "preinstall" = ["echo No hook"]
    #   "postinstall" = ["echo No hook"]
    #   "boot-preconfig" = [
    #     # "${var.image_location == "" ? "exit 0" : "echo Getting archives"}",
    #     "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
    #     "sudo mv /tmp/load_image.sh /opt/ibm/scripts/",
    #     "sudo chmod a+x /opt/ibm/scripts/load_image.sh",
    #     "/opt/ibm/scripts/load_image.sh -p ${var.image_location} -r ${local.registry_server} -c ${local.docker_password}"
    #   ]
    # }

}

output "ICP Console load balancer DNS (external)" {
  value = "${ibm_lbaas.master-lbaas.vip}"
}

output "ICP Proxy load balancer DNS (external)" {
  value = "${ibm_lbaas.proxy-lbaas.vip}"
}

output "ICP Console URL" {
  value = "https://${ibm_lbaas.master-lbaas.vip}:8443"
}

output "ICP Registry URL" {
  value = "${ibm_lbaas.master-lbaas.vip}:8500"
}

output "ICP Kubernetes API URL" {
  value = "https://${ibm_lbaas.master-lbaas.vip}:8001"
}

output "ICP Admin Username" {
  value = "admin"
}

output "ICP Admin Password" {
  value = "${local.icppassword}"
}
