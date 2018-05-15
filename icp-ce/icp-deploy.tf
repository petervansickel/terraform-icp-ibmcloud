##################################
### Deploy ICP to cluster
##################################
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy.git?ref=2.2.1"

    # Provide IP addresses for boot, master, mgmt, va, proxy and workers
    boot-node = "${var.boot["nodes"] == 0 ? ibm_compute_vm_instance.icp-master.0.ipv4_address_private :  ibm_compute_vm_instance.icp-boot.ipv4_address_private }"
    icp-host-groups = {
        master = ["${ibm_compute_vm_instance.icp-master.*.ipv4_address_private}"]
        proxy = ["${ibm_compute_vm_instance.icp-proxy.*.ipv4_address_private}"]
        worker = ["${ibm_compute_vm_instance.icp-worker.*.ipv4_address_private}"]
        mgmt = ["${ibm_compute_vm_instance.icp-mgmt.*.ipv4_address_private}"]
        va = ["${ibm_compute_vm_instance.icp-va.*.ipv4_address_private}"]
    }

    # Provide desired ICP version to provision
    icp-version = "${var.icp_inception_image}"
    image_location = "${var.image_location}"

    # TODO: Need to correct spelling of parallel in terraform-icp-deploy variables.tf, main.tf and where-ever else.
    parallell-image-pull = true

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out automatically */
    cluster_size  = "${var.master["nodes"] +
        var.worker["nodes"] +
        var.proxy["nodes"] +
        var.mgmt["nodes"] +
        var.va["nodes"]}"

    ###################################################################################################################################
    ## You can feed in arbitrary configuration items in the icp_configuration map.
    ## Available configuration items availble from https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html
    icp_config_file = "./icp-config.yaml"
    icp_configuration = {
      "network_cidr"                    = "${var.network_cidr}"
      "service_cluster_ip_range"        = "${var.service_network_cidr}"
      "cluster_access_ip"               = "${var.cluster_vip}"
      "proxy_access_ip"                 = "${var.proxy_vip}"
      "cluster_vip"                     = "${var.cluster_vip}"
      "proxy_vip"                       = "${var.proxy_vip}"
      "vip_iface"                       = "${var.cluster_vip_iface}"
      "proxy_vip_iface"                 = "${var.proxy_vip_iface}"
      "cluster_lb_address"              = "${var.cluster_lb_address}"
      "proxy_lb_address"                = "${var.proxy_lb_address}"
      #"vip_manager"                     = "etcd"
      "cluster_name"                    = "${var.instance_name}-cluster"
      "calico_ip_autodetection_method"  = "first-found"
      "default_admin_password"          = "${var.icppassword}"
      "disabled_management_services"    = [ "${var.va["nodes"] == 0 ? "va" : "" }" ]
      "image_repo"                      = "${var.image_repo}"

    }

    # We will let terraform generate a new ssh keypair
    # for boot master to communicate with worker and proxy nodes
    # during ICP deployment
    generate_key = true

    # SSH user and key for terraform to connect to newly created VMs
    # ssh_key is the private key corresponding to the public assumed to be included in the template
    ssh_user        = "${var.ssh_user}"
    ssh_key_base64  = "${base64encode(file(var.ssh_keyfile))}"
    ssh_agent       = false
}
