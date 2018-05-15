##### SoftLayer/IBMCloud Access Credentials ######

# Provide values for these in terraform.tfvars
variable "sl_username" { description = "IBM Cloud (aka SoftLayer) user name." }
variable "sl_api_key" { description = "IBM Cloud (aka SoftLayer) API key." }


variable "key_name" { description = "Name or reference of SSH key to provision IBM Cloud instances with" }

variable "icp_admin_password" {
  description = "ICP Admin Users password password. 'Generate' generates a new random password"
  default     = "Generate"
}


##### Common VM specifications ######
# Provide values for these in terraform.tfvars
variable "datacenter" { }

variable "instance_name" {
  description = "Identifier used as the root of the ICP cluster name with '-cluster' appended to it."
  default = "my"
}

variable "deployment" {
         description = "Identifier prefix added to the host names."
         default = "dev01"
}


variable "os_reference_code" {
         description = "IBM Cloud OS reference code to determine OS, version, word length"
         default = "CENTOS_7_64"
}

variable "icp_version" {
  description = "IBM Cloud Private version to install."
  default = "latest"
}

variable "domain" {
  description = "Specify domain name to be used for linux customization on the VMs, or leave blank to use <instance_name>.icp"
  default     = ""
}

variable "staticipblock" {
  description = "Specify start unused static ip cidr block to assign IP addresses to the cluster, e.g. 172.16.0.0/16.  Set to 0.0.0.0/0 for DHCP."
  default     = "0.0.0.0/0"
}

variable "staticipblock_offset" {
  description = "Specify the starting offset of the staticipblock to begin assigning IP addresses from.  e.g. with staticipblock 172.16.0.0/16, offset of 10 will cause IP address assignment to begin at 172.16.0.11."
  default     = 0
}

variable "gateway" {
  description = "Default gateway for the newly provisioned VMs. Leave blank to use DHCP"
  default     = ""
}

variable "netmask" {
  description = "Netmask in CIDR notation when using static IPs. For example 16 or 24. Set to 0 to retrieve from DHCP"
  default     = 0
}

variable "dns_servers" {
  description = "DNS Servers to configure on VMs"
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable "cluster_vip" {
  description = "Virtual IP for Master Console"
  default     = "127.0.1.1"
}

variable "proxy_vip" {
  description = "Virtual IP for Proxy Nodes"
  default     = "127.0.1.1"
}

variable "cluster_lb_address" {
  description = "External LoadBalancer address for Master Console"
  default     = "none"
}

variable "proxy_lb_address" {
  description = "External Load Balancer address for Proxy Node"
  default     = "none"
}

variable "cluster_vip_iface" {
  description = "Network Interface for Virtual IP for Master Console"
  default     = "eth0"
}

variable "proxy_vip_iface" {
  description = "Network Interface for Virtual IP for Proxy Nodes"
  default     = "eth0"
}

##### ICP Instance details ######

variable "boot" {
  type = "map"

  default = {
    nodes       = "0"
    cpu_cores   = "2"
    disk_size   = "200" // GB
    local_disk  = false
    memory      = "8192"
    network_speed = "1000"
    private_network_only = false
    hourly_billing=true
  }
}


variable "master" {
  type = "map"

  default = {
    nodes       = "1"
    cpu_cores   = "4"
    disk_size   = "300" // GB
    local_disk  = false
    memory      = "16384"
    network_speed = "1000"
    private_network_only = false
    hourly_billing=true
  }
}

variable "mgmt" {
  type = "map"

  default = {
    nodes       = "1"
    cpu_cores   = "4"
    disk_size   = "300" // GB
    local_disk  = false
    memory      = "16384"
    network_speed = "1000"
    private_network_only = false
    hourly_billing=true
  }
}

variable "proxy" {
  type = "map"

  default = {
    nodes       = "1"
    cpu_cores   = "2"
    disk_size   = "200" // GB
    local_disk  = true
    memory      = "8192"
    network_speed= "1000"
    private_network_only=false
    hourly_billing=true
  }
}

variable "va" {
  type = "map"

  default = {
    nodes       = "1"
    cpu_cores   = "4"
    disk_size   = "500" // GB
    local_disk  = false
    memory      = "16384"
    network_speed = "1000"
    private_network_only = false
    hourly_billing=true
  }
}


variable "worker" {
  type = "map"

  default = {
    nodes       = "2"
    cpu_cores   = "4"
    disk_size   = "200" // GB
    local_disk  = true
    memory      = "16384"
    network_speed= "1000"
    private_network_only=false
    hourly_billing=true
  }
}

variable "docker_package_location" {
  description = "URI for docker package location, e.g. http://<myhost>/icp-docker-17.09_x86_64.bin or nfs:<myhost>/icp-docker-17.09_x86_64.bin"
  default     = ""
}

variable "image_location" {
  description = "URI for image package location, e.g. http://<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz or nfs:<myhost>/ibm-cloud-private-x86_64-2.1.0.2.tar.gz"
  default     = ""
}

variable "image_repo" {
  description = "Registry prefix to install all ICP images from"
  default     = "ibmcom"
}

variable "registry_mount_src" {
  description = "Mount point containing the shared registry directory for /var/lib/registry"
  default     = ""
}

variable "registry_mount_type" {
  description = "Mount Type of registry shared storage filesystem"
  default     = "nfs"
}

variable "registry_mount_options" {
  description = "Additional mount options for registry shared directory"
  default     = "defaults"
}

variable "audit_mount_src" {
  description = "Mount point containing the shared registry directory for /var/lib/icp/audit"
  default     = ""
}

variable "audit_mount_type" {
  description = "Mount Type of registry shared storage filesystem"
  default     = "nfs"
}

variable "audit_mount_options" {
  description = "Additional mount options for audit shared directory"
  default     = "defaults"
}

variable "icppassword" {
  description = "Password for the initial admin user in ICP"
  default     = "admin"
}

variable "ssh_user" {
  description = "Username which terraform will use to connect to newly created VMs during provisioning"
  default     = "root"
}

variable "ssh_keyfile" {
  description = "Location of private ssh key to connect to newly created VMs during provisioning"
  default     = "~/.ssh/id_rsa"
}

variable "icp_inception_image" {
  description = "ICP image to use for installation"
  default     = "ibmcom/icp-inception:2.1.0.2-ee"
}

variable "network_cidr" {
  description = "Pod network CIDR "
  default     = "192.168.0.0/16"
}


variable "service_network_cidr" {
  description = "Service network CIDR "
  default     = "10.10.10.0/24"
}
