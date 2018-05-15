provider "ibm" {
    softlayer_username = "${var.sl_username}"
    softlayer_api_key = "${var.sl_api_key}"
}

data "ibm_compute_ssh_key" "public_key" {
  label = "${var.key_name}"
}

# Generate a random string in case user wants us to generate admin password
resource "random_id" "adminpassword" {
  byte_length = "4"
}


#### VMs for an ICP deployment

resource "ibm_compute_vm_instance" "icp-boot" {
    hostname = "${var.deployment}-boot"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.boot["cpu_cores"]}"
    memory = "${var.boot["memory"]}"
    network_speed = "${var.boot["network_speed"]}"
    hourly_billing = "${var.boot["hourly_billing"]}"
    local_disk = "${var.boot["local_disk"]}"
    private_network_only = "${var.boot["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Boot"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Boot machine for ICP deployment"
}

resource "ibm_compute_vm_instance" "icp-master" {
    count = "${var.master["nodes"]}"
    hostname = "${format("${lower(var.deployment)}-master%02d", count.index + 1) }"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.master["cpu_cores"]}"
    memory = "${var.master["memory"]}"
    network_speed = "${var.master["network_speed"]}"
    hourly_billing = "${var.master["hourly_billing"]}"
    local_disk = "${var.master["local_disk"]}"
    private_network_only = "${var.master["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Master"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Master node for ICP deployment"
}

resource "ibm_compute_vm_instance" "icp-mgmt" {
    count = "${var.mgmt["nodes"]}"
    hostname = "${format("${lower(var.deployment)}-mgmt%02d", count.index + 1) }"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.mgmt["cpu_cores"]}"
    memory = "${var.mgmt["memory"]}"
    network_speed = "${var.mgmt["network_speed"]}"
    hourly_billing = "${var.mgmt["hourly_billing"]}"
    local_disk = "${var.mgmt["local_disk"]}"
    private_network_only = "${var.mgmt["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Management"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Management node for ICP deployment"
}

resource "ibm_compute_vm_instance" "icp-va" {
    count = "${var.va["nodes"]}"
    hostname = "${format("${lower(var.deployment)}-va%02d", count.index + 1) }"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.va["cpu_cores"]}"
    memory = "${var.va["memory"]}"
    network_speed = "${var.va["network_speed"]}"
    hourly_billing = "${var.va["hourly_billing"]}"
    local_disk = "${var.va["local_disk"]}"
    private_network_only = "${var.va["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Management"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Vulnerability Advisor node for ICP deployment"
}

resource "ibm_compute_vm_instance" "icp-proxy" {
    count = "${var.proxy["nodes"]}"
    hostname = "${format("${lower(var.deployment)}-proxy%01d", count.index + 1) }"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.proxy["cpu_cores"]}"
    memory = "${var.proxy["memory"]}"
    network_speed = "${var.proxy["network_speed"]}"
    hourly_billing = "${var.proxy["hourly_billing"]}"
    local_disk = "${var.proxy["local_disk"]}"
    private_network_only = "${var.proxy["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Proxy"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Proxy node for ICP deployment"
}


resource "ibm_compute_vm_instance" "icp-worker" {
    count = "${var.worker["nodes"]}"
    hostname = "${format("${lower(var.deployment)}-worker%01d", count.index + 1) }"
    domain = "${var.domain}"
    os_reference_code = "${var.os_reference_code}"
    datacenter = "${var.datacenter}"
    cores = "${var.worker["cpu_cores"]}"
    memory = "${var.worker["memory"]}"
    network_speed = "${var.worker["network_speed"]}"
    hourly_billing = "${var.worker["hourly_billing"]}"
    local_disk = "${var.worker["local_disk"]}"
    private_network_only = "${var.worker["private_network_only"]}"
    tags = ["${var.deployment}", "ICP-Worker"]
    ipv6_enabled = true
    secondary_ip_count = 4

    # Permit an ssh loging for the key owner.
    # You an have multiple keys defined.
    ssh_key_ids = ["${data.ibm_compute_ssh_key.public_key.id}"]

    notes = "Worker node for ICP deployment"
}
