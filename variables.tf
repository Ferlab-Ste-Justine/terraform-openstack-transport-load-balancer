variable "name" {
  description = "Name of the vm"
  type = string
}

variable "network_port" {
  description = "Network port to assign to the node. Should be of type openstack_networking_port_v2"
  type        = any
}

variable "server_group" {
  description = "Server group to assign to the node. Should be of type openstack_compute_servergroup_v2"
  type        = any
}

variable "image_id" {
    description = "ID of the vm image used to provision the node"
    type = string
}

variable "flavor_id" {
  description = "ID of the VM flavor"
  type = string
}

variable "keypair_name" {
  description = "Name of the keypair that will be used by admins to ssh to the node"
  type = string
}

variable "ssh_host_key_rsa" {
  type = object({
    public = string
    private = string
  })
  default = {
    public = ""
    private = ""
  }
}

variable "ssh_host_key_ecdsa" {
  type = object({
    public = string
    private = string
  })
  default = {
    public = ""
    private = ""
  }
}

variable "load_balancer" {
  description = "Properties of the load balancer"
  type = object({
    cluster = string
    node_id = string
  })
  default     = {
    cluster = ""
    node_id = ""
  }
}

variable "control_plane" {
  description = "Properties of the control plane"
  type = object({
    log_level        = string
    version_fallback = string
    server           = object({
      port                = number
      max_connections     = number
      keep_alive_time     = string
      keep_alive_timeout  = string
      keep_alive_min_time = string
    })
    etcd        = object({
      key_prefix         = string
      endpoints          = list(string)
      connection_timeout = string
      request_timeout    = string
      retries            = number
      ca_certificate     = string
      client             = object({
        certificate = string
        key         = string
        username    = string
        password    = string
      })
    })
  })
}

variable "ssh_tunnel" {
  description = "Setting for restricting the bastion access via an ssh tunnel only"
  type        = object({
    enabled = bool
    ssh     = object({
      user           = string
      authorized_key = string
    })
  })
  default     = {
    enabled = false
    ssh     = {
      user           = ""
      authorized_key = ""
    }
  }
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  sensitive = true
  type = object({
    enabled = bool
    load_balancer_tag = string
    control_plane_tag = string
    node_exporter_tag = string
    metrics = object({
      enabled = bool
      port    = number
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
    etcd = object({
      enabled = bool
      key_prefix = string
      endpoints = list(string)
      ca_certificate = string
      client = object({
        certificate = string
        key = string
        username = string
        password = string
      })
    })
  })
  default = {
    enabled = false
    load_balancer_tag = ""
    control_plane_tag = ""
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
    etcd = {
      enabled = false
      key_prefix = ""
      endpoints = []
      ca_certificate = ""
      client = {
        certificate = ""
        key = ""
        username = ""
        password = ""
      }
    }
  }
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled  = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers  = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools    = list(object({
      url     = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit     = number
    })
  })
  default     = {
    enabled  = false
    servers  = []
    pools    = []
    makestep = {
      threshold = 0,
      limit     = 0
    }
  }
}

variable "custom_certificates" {
  description = "A set of custom certificate-key pairs that can be added to the vm and configured in envoy to perform tls termination"
  type        = list(object({
    certificate = object({
      path  = string
      content = string
    })
    key = object({
      path  = string
      content = string
    })
  }))
  default     = []
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type        = bool
  default     = true
}