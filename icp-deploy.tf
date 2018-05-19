##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/jkwong888/terraform-module-icp-deploy.git"

    # Provide IP addresses for boot, master, mgmt, va, proxy and workers
    boot-node = "${ibm_compute_vm_instance.icp-boot.ipv4_address_private}"
    bastion_host = "${ibm_compute_vm_instance.icp-boot.ipv4_address}"
    icp-host-groups = {
        master = ["${ibm_compute_vm_instance.icp-master.*.ipv4_address_private}"]
        proxy = ["${ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private}"]
        worker = ["${ibm_compute_vm_instance.icp-worker.*.ipv4_address_private}"]
        mgmt = ["${ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private}"]
        va = ["${ibm_compute_vm_instance.icp-va.*.ipv4_address_private}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${local.inception_image}"

    # TODO: Need to correct spelling of parallel in terraform-icp-deploy variables.tf, main.tf and where-ever else.
    parallell-image-pull = true

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${1 + var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"] + var.mgmt["nodes"] + var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_config_file = "./icp-config.yaml"
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_lb_address"              = "${var.master["nodes"] > 1 ? "${ibm_lbaas.master-lbaas.vip}" : ""}"
      "proxy_lb_address"                = "${var.proxy["nodes"] > 1 ? "${ibm_lbaas.proxy-lbaas.vip}" : ""}"
      "cluster_CA_domain"               = "${var.master["nodes"] > 1 ? ibm_lbaas.master-lbaas.vip : ""}"
      "cluster_name"                    = "${var.deployment}"
      "calico_ip_autodetection_method"  = "interface=eth0"
      "default_admin_password"          = "${var.icppassword != "" ? "${var.icppassword}" : "${random_id.adminpassword.hex}"}"
      "disabled_management_services"    = [
          "${var.va["nodes"] == 0 ? "va" : "" }"
      ]
      "image_repo"                      = "${dirname(local.inception_image)}"
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
}
