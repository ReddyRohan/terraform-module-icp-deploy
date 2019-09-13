# Username and password for the initial admin user
### ICP node topology
variable "icp-master" {
  type        = "list"
  description =  "IP address of ICP Masters. First master will also be boot master. CE edition only supports single master "
  default     = []
}

variable "icp-worker" {
  type        = "list"
  description =  "IP addresses of ICP Worker nodes."
  default     = []
}

variable "icp-proxy" {
  type        = "list"
  description =  "IP addresses of ICP Proxy nodes."
  default     = []
}

variable "icp-management" {
  type        = "list"
  description = "IP addresses of ICP Management Nodes, if management is to be separated from master nodes. Optional"
  default     = []
}

variable "cluster_size" {
  description = "Define total clustersize. Workaround for terraform issue #10857."
}

### ICP inception settings

variable "image_location" {
  description = "NFS or HTTP location where image tarball can be accessed"
  default     = ""
}

variable "image_locations" {
  type        = "list"
  description = "List of HTTP locations where image tarballs can be accessed. Typically used in multi-arch deployment"
  default     = []
}

variable "image_location_user" {
  description = "Username if authentication required for image_location"
  default     = ""
}

variable "image_location_pass" {
  description = "Pass if authentication required for image_location"
  default     = ""
}

variable "cluster-directory" {
  description = "Location to use for the cluster directory"
  default     = "/opt/ibm/cluster"
}

variable  "icp-inception" {
  description = "Version of ICP to provision. For example 3.1.2 or myuser:mypass@registry/ibmcom/icp-inception:3.1.2-ee"
  default = ""
}

variable "install-command" {
  description = "Installer command to run"
  default     = "install"
}

variable "install-verbosity" {
  description = "Verbosity of ansible installer output. -v to -vvvv where the maximum level includes connectivity information"
  default     = ""
}

### SSH CONNECTION DETAILS

variable "ssh_user" {
  description = "Username to ssh into the ICP cluster. This is typically the default user with for the relevant cloud vendor"
  default     = "root"
}

variable "cluster_dir_owner" {
  description = "Username to own the ICP cluster directory after installation completes; defaults to ssh_user"
  default     = ""
}

variable "ssh_key_base64" {
  description = "base64 encoded content of private ssh key"
  default     = ""
}

variable "ssh_agent" {
  description = "Enable or disable SSH Agent. Can correct some connectivity issues. Default: true (enabled)"
  default     = true
}

variable "bastion_host" {
  description = "Specify hostname or IP to connect to nodes through a SSH bastion host. Assumes same SSH key and username as cluster nodes"
  default     = ""
}

variable "generate_key" {
  description = "Whether to generate a new ssh key for use by ICP Boot Master to communicate with other nodes"
  default     = true
}

variable "icp_pub_key" {
  description = "Public ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false"
  default     = ""
}

variable "icp_priv_key" {
  description = "Private ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false"
  default     = ""
}

### ICP CONFIGURATION

/*
  Configuration file is generated from items in the following order
  1. config.yaml shipped with ICP (if config_strategy = merge, else blank)
  2. config.yaml specified in icp_config_file
  3. key: value items specified in icp_configuration

*/
variable "icp_config_file" {
  description = "Yaml configuration file for ICP installation"
  default     = "/dev/null"
}


variable "icp_configuration" {
  description = "Configuration items for ICP installation."
  type        = "map"
  default     = {
    "network_cidr"                   = var.pod_network_cidr
    "service_cluster_ip_range"       = var.service_network_cidr
    "cluster_access_ip"              = google_compute_instance.icp-master.network_interface[0].access_config[0].nat_ip
    "proxy_lb_address"               = google_compute_address.icp-proxy.address
    "cluster_CA_domain"              = var.cluster_cname != "" ? var.cluster_cname : "${var.instance_name}-cluster.icp"
    "cluster_name"                   = "${var.instance_name}-cluster.icp"
    "kubelet_nodename"               = "hostname"
    "calico_ip_autodetection_method" = "first-found"
    "firewall_enabled"               = substr(var.image["family"], 0, 4) == "rhel" ? "true" : "false" # this is true by default in rhel but false in ubuntu
    # An admin password will be generated if not supplied in terraform.tfvars
    "default_admin_password" = local.icppassword
    # This is the list of disabled management services
    "management_services"                = local.disabled_management_services
    "private_registry_enabled"           = var.registry_server != "" ? "true" : "false"
    "private_registry_server"            = local.registry_server
    "image_repo"                         = local.image_repo      # Will either be our private repo or external repo
    "docker_username"                    = local.docker_username # Will either be username generated by us or supplied by user
    "docker_password"                    = local.docker_password # Will either be username generated by us or supplied by user
    "kube_apiserver_extra_args"          = ["--cloud-provider=gce", "--cloud-config=/etc/cfc/conf/gce.conf"]
    "kube_controller_manager_extra_args" = ["--cloud-provider=gce", "--cloud-config=/etc/cfc/conf/gce.conf", "--allocate-node-cidrs=true"]
    "kubelet_extra_args"                 = ["--cloud-provider=gce"]
    # TODO: ICP 3.1.1+ use the routes created by the GCE cloud provider
    # and host-local IPAM, calico in policy-only mode
    # in ICP 3.1.0 and below, we reconfigure calico after installation
    "calico_networking_backend" = "none"
    "calico_ipam_type"          = "host-local"
    "calico_ipam_subnet"        = "usePodCidr"
  }

}


variable "config_strategy" {
  description  = "Strategy for original config.yaml shipped with ICP. Default is merge, everything else means override"
  default      = "merge"

}

variable "icp-host-groups" {
  description = "Map of host groups and IPs in the cluster. Needs at least master, proxy and worker"
  type        = "map"
  default     = {}
}

variable "boot-node" {
  description = "Node where ICP installer will be run from. Often first master node, but can be different"
  default     = ""
}

### HOOKS

variable "hooks" {
  description = "Hooks into different stages in the cluster setup process; each must be a list"
  type        = "map"
  default     = {
    cluster-preconfig  = ["echo -n"]
    cluster-postconfig = ["echo -n"]
    boot-preconfig     = ["echo -n"]
    preinstall         = ["echo -n"]
    postinstall        = ["echo -n"]
  }
}

variable "local-hooks" {
  description = "Local hooks into different stages in the cluster setup process; each must be a single command"
  type        = "map"
  default     = {
    local-preinstall   = "echo -n"
    local-postinstall  = "echo -n"
  }
}

variable "on_hook_failure" {
  description = "Behavior when hooks fail. Anything other than `fail` will `continue`"
  default     = "fail"
}

### DOCKER PARAMETERS

variable "docker_image_name" {
  description = "Name of docker image to install; only supported for Ubuntu"
  default = "docker-ce"
}

variable "docker_version" {
  description = "Version of docker image to install; only supported for Ubuntu"
  default = "latest"
}

variable "docker_package_location" {
  description = "http or nfs location of docker installer which ships with ICP. Option for RHEL which does not support docker-ce"
  default     = ""
}

### LOCAL VARIABLES

locals {
  spec-icp-ips  = "${distinct(compact(concat(list(var.boot-node), var.icp-master, var.icp-proxy, var.icp-management, var.icp-worker)))}"
  host-group-ips = "${distinct(compact(concat(list(var.boot-node), keys(transpose(var.icp-host-groups)))))}"
  icp-ips       = "${distinct(concat(local.spec-icp-ips, local.host-group-ips))}"
  cluster_size  = "${length(concat(var.icp-master, var.icp-proxy, var.icp-worker, var.icp-management))}"
  ssh_key       = "${base64decode(var.ssh_key_base64)}"
  boot-node     = "${element(compact(concat(list(var.boot-node),var.icp-master)), 0)}"

  cluster_dir_owner = "${var.cluster_dir_owner == "" ? var.ssh_user : var.cluster_dir_owner}"
}
