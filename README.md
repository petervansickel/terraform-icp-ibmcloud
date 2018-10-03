# Terraform ICP IBM Cloud

This Terraform example configurations uses the [IBM Cloud  provider](https://ibm-cloud.github.io/tf-ibm-docs/index.html) to provision virtual machines on IBM Cloud Infrastructure (SoftLayer)
and [TerraForm Module ICP Deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy) to prepare VSIs and deploy [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/) on them in Highly Available configuraiton.  This Terraform template automates best practices learned from installing ICP on IBM Cloud Infrastructure.

## Architecture Diagram

![Architecture](./static/icp_ibmcloud.png)

## Pre-requisites

* Working copy of [Terraform](https://www.terraform.io/intro/getting-started/install.html)
  * As of this writing, IBM Cloud Terraform provider is not in the main Terraform repository and must be installed manually.  See [these steps](https://ibm-cloud.github.io/tf-ibm-docs/index.html#using-terraform-with-the-ibm-cloud-provider).  We tested this automation script against v0.9.1 of the Terraform provider.
* The template is tested on VSIs based on Ubuntu 16.04.  RHEL is not supported in this automation.

### Environment preparation

There are two options to provide the IBM Cloud Private binaries necessary to install:
1. Download the IBM Cloud Private docker and installation binaries and save them to the `icp-install` directory.  
2. (Preferred) Create an NFS mount point with IBM Cloud File Storage and upload the binaries there. See below to the [Setup IBM Cloud File Storage](#setup-ibm-cloud-file-storage) for this purpose.
3. Create an HTTP endpoint and upload the binaries there.

### Using the Terraform templates

1. git clone the repository

1. Create a `terraform.tfvars` file to reflect your environment.  Please see [variables.tf](variables.tf) and below tables for variable names and descriptions.  Here is an example `terraform.tfvars` file:


```
sl_username = "<my username>"
sl_api_key = "<my api key>"
key_name = ["my-ssh-key"]
datacenter = "dal13"
domain = "dal13.icp.com"
os_reference_code = "UBUNTU_16_64"
icp_inception_image = "ibmcom/icp-inception:2.1.0.2-ee"
image_location = "icp-install/ibm-cloud-private-x86_64-2.1.0.2.tar.gz"
docker_package_location = "icp-install/icp-docker-17.09_x86_64.bin"

master = {
  nodes = "3"
}

proxy = {
  nodes = "3"
}

worker = {
  nodes = "3"
}

mgmt = {
  nodes = "3"
}

va = {
  nodes = "3"
}
```

1. Run `terraform init` to download depenencies (modules and plugins)

1. Run `terraform plan` to investigate deployment plan

1. Run `terraform apply` to start deployment.


### Automation Notes

#### Boot Node private registry

The automation will create a boot node VSI that the Terraform automation SSHes to.  The automation performs the following steps on the boot node:

1. Install docker-ce from the official docker repo.
1. Set up [direct-lvm](https://docs.docker.com/storage/storagedriver/device-mapper-driver/#configure-direct-lvm-mode-for-production) mode using the docker volume.
1. Copy the binary packages (specified in `docker_package_location` and `image_location`) to `/tmp` on the boot node.
1. Load all images into the local docker registry.
1. Create a private image registry and push all of the ICP images into it.

The remainder of the automation installs ICP using the private image registry containing the ICP images.

#### Security Groups

The automation leverages Security Groups to lock down public and private access to the cluster.  

- Inbound communication to the master and proxy nodes are only permitted on ports from the private subnet that the LBaaS is provisioned on.  
- Inbound SSH to the boot node is permitted from all addresses on the internet.  
- All outbound communication is allowed.  
- All other communication is only permitted between cluster nodes.

#### LBaaS

The automation exposes the Master control plane to the Internet on:
- TCP port 8443 (master console)
- TCP port 8500 (private registry)
- TCP port 8001 (Kubernetes API)
- TCP port 9443 (OIDC authentication endpoint)

The automation exposes the Proxy nodes to the internet on:
- TCP port 443 (https)
- TCP port 80 (http)

### Terraform configuration

Please see [variables.tf](variables.tf) for additional parameters.

| name | required                        | value        |
|----------------|------------|--------------|
| `sl_username`   | yes          | Username for IBM Cloud infrastructure account |
| `sl_api_key`   | yes          | API Key for IBM Cloud infrastructure account |
| `key_name`   | no           | Array of SSH keys to add to `root` for all created VSI instances.  Note that the automation generates its own SSH keys so these are additional keys that can be used for access |
| `datacenter`   | yes           | Datacenter to place all objects in |
| `os_reference_code`   | yes           | OS to install on the VSIs.  Use the [API](https://api.softlayer.com/rest/v3/SoftLayer_Virtual_Guest_Block_Device_Template_Group/getVhdImportSoftwareDescriptions.json?objectMask=referenceCode) to determine valid values. Only Ubuntu 16.04 was tested. Note that the boot node OS can be specified separately (defaults to `UBUNTU_16_64` to save licensing costs). |
| `icp_inception_image` | yes | The ICP installer image to use.  This corresponds to the version of ICP to install. |
| `image_location` | no | The local path to where the binaries are saved. |
| `docker_package_location` | no | The local path to where the IBM-provided docker installation binary is saved. If not specified and using Ubuntu, will install latest `docker-ce` off public repo. |
| `private_network_only` | no | Specify true to remove the cluster from the public network. If public network access is disabled, note that to allow outbound internet access you will require a Gateway Appliance on the VLAN to do Source NAT. Additionally, the automation requires SSH access to the boot node to provision ICP, so a VPN tunnel may be required.  The LBaaS for both the master and the control plane will still be provisioned on the public internet, but the cluster nodes will not have public addresses configured. |
| `private_vlan_router_hostname` | no | Private VLAN router to place all VSIs behind.  e.g. bcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. This option should be used when setting `private_network_only` to true along with `private_vlan_number` using a private VLAN that is routed with a Gateway Appliance. |
| `private_vlan_number` | no | Private VLAN number to place all VSIs on.  e.g. 1211. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. This option should be used when setting `private_network_only` to true along with `private_vlan_router_hostname`, using a private VLAN that is routed with a Gateway Appliance.|
| `public_vlan_router_hostname` | no | Public VLAN router to place all VSIs behind.  e.g. fcr01a. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. |
| `public_vlan_number` | no | Public VLAN number to place all VSIs on.  e.g. 1211. See Network > IP Management > VLANs in the portal. Leave blank to let the system choose. |
| `icppassword` | no | ICP administrator password.  One will be generated if not set. |

### Setup IBM Cloud File Storage to Host ICP Binaries

#### Create File Storage

1.  From the [IBM Cloud Console](https://console.bluemix.net), select [Infrastructure](https://control.bluemix.net) from the left sidebar menu.
2.  In the IBM Cloud Infrastructure page, expand the **Storage** dropdown and select [File Storage](https://control.bluemix.net/storage/file).
3.  Select [Order File Storage](https://control.bluemix.net/storage/order?storageType=FILE) from the upper-right side of the window.
4.  Select the datacenter most appropriate for your installation, a minimum of at least 20GB of storage size, and the desired amount of IOPS (_generally 0.25 or 2 are sufficient_). Then click **Place Order**.
5.  Once created, click on your File Storage instance from the list shown at https://control.bluemix.net/storage/file.
6.  Make note of the **Mount Point** field as this will be used later on.
7.  Click on the **Actions** dropdown from the upper-right and select **Authorize Host**.
8.  You can authorize specific devices, subnets or IP addresses to communicate with your file storage instance.  If you will have a number of systems deploying Terraform-based ICP installations, authorizing by Subnet is the preferred option.  If you are only doing one or two installations, authorizing by specific Devices can be the more secure option.  Determine your preferred method here and authorize hosts so that your jump server VM will be able to communicate with the file storage.
9.  Click **Submit**.

#### Create Jump Server for file uploads

You will now need to create jump server to upload the initial files into IBM Cloud and then onto the network-attached IBM Cloud File Storage

1.  Go to the [Device List](https://control.bluemix.net/devices) and click [Order Devices](https://console.bluemix.net/catalog/).
2.  Select to create a **Virtual Server** and then a **Public Virtual Server**.
3.  Select a Location that matches as closely as possible to the Datacenter selected for your previously created File Storage.
4.  The **Balanced B1.2x4** profile is the minimum recommended option for the jump server in this case.
5.  You will want to add an SSH Key to the system to login later on. 
6.  Ubuntu is the preferred option for Linux distributions, but others are acceptable as well.  However, licensing may be an issue with other Linux distributions.
7.  Select **100 GB** of SAN for the **Attached Storage Disks**.
8.  For both the **Private Security Group** and the **Public Security Group** you will want to check **allow_ssh** to copy files into the system.
9.  Click **Provision**.

#### Copy Tarball into IBM Cloud

1.  Once the Jump Server has been provisioned, verify that you can SSH into the system using the specified SSH key at instance provisioning time and the associated username (generally **root**).
2.  Once you have verified SSH signin, now copy the files you have in the `icp-install` directory to the remote machine via `scp`.  Note you will need to create the remote directory that you specify in the `scp` command.  
        `$ scp -r -i ~/.ssh/your_ssh_key icp-install root@{Jump_Server_IP_Address}:/root/icp-install`

#### Mount and Copy to File Storage

Once the files have been copied from your local system to your jump server, you can now mount and copy the files into your file storage.

1.  On the Jump Server, create a mount point directory on the system.  This is generally done underneath the `/mnt` parent directory, similar to `mkdir /mnt/filestorage`.
2.  Recalling the **Mount Point** from the earlier File Storage details screen, you can now mount the file storage to the jump server via `mount {File Storage Mount Point} /mnt/filestorage`.
3.  Validate the mount succeeded by running a simple `touch /mnt/filestorage/test.txt` command.
4.  Create any neccessary sub-directories in `/mnt/filestorage` for how you would like to arrange your stored binaries.
5.  Copy the files into the mounted directory.  Due to the nature of the large files and across network distances, the normal Unix copy command, `cp`, isn't the most preferred option.  Instead you can use `rsync` to see file status as items are copied over.  You can run this command similar to the normal copy, but with the benefit of receiving progress indicator updates.  
        `$ rsync -ahr --progress /root/icp-install /mnt/filestorage/icp-files`

#### Update terraform.tfvars

Once the files have been copied into the IBM Cloud File Storage instance, you will need to update your `terraform.tfvars` file to point to the remotely-stored binaries.

1.  In `terraform.tfvars`, create a line similar to the following:  
`image_location = "nfs:{File Storage Mount Point}/{your created subdirectories}/ibm-cloud-private-x86_64-2.1.0.3.tar.gz"`
2.  Now you are ready to run your `terraform plan` & `terraform apply` commands!
3.  If you will no longer need to copy files into the IBM Cloud File Storage instance, your jump server can be destroyed.
