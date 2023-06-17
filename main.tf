module "ssh_tunnel_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//ssh-tunnel?ref=v0.8.0"
  ssh_host_key_rsa = var.ssh_host_key_rsa
  ssh_host_key_ecdsa = var.ssh_host_key_ecdsa
  tunnel = {
    ssh = var.ssh_tunnel.ssh
    accesses = [{
      host = "127.0.0.1"
      port = "*"
    }]
  }
}

module "transport_load_balancer_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//transport-load-balancer?ref=v0.8.0"
  install_dependencies = var.install_dependencies
  control_plane = var.control_plane
  load_balancer = {
    cluster = var.load_balancer.cluster != "" ? var.load_balancer.cluster : var.name
    node_id = var.load_balancer.node_id != "" ? var.load_balancer.node_id : var.name
  }
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.8.0"
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.8.0"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.8.0"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = [
      {
        tag     = var.fluentbit.load_balancer_tag
        service = "transport-load-balancer.service"
      },
      {
        tag     = var.fluentbit.control_plane_tag
        service = "transport-control-plane.service"
      },
      {
        tag     = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }
    ]
    forward = var.fluentbit.forward
  }
  etcd    = var.fluentbit.etcd
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = var.name
            ssh_host_key_rsa = var.ssh_host_key_rsa
            ssh_host_key_ecdsa = var.ssh_host_key_ecdsa
            custom_certificates = var.custom_certificates
          }
        )
      },
      {
        filename     = "transport_load_balancer.cfg"
        content_type = "text/cloud-config"
        content      = module.transport_load_balancer_configs.configuration
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      }
    ],
    var.ssh_tunnel.enabled ? [{
      filename     = "ssh_tunnel.cfg"
      content_type = "text/cloud-config"
      content      = module.ssh_tunnel_configs.configuration
    }] : [],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "openstack_compute_instance_v2" "transport_load_balancer" {
  name            = var.name
  image_id        = var.image_id
  flavor_id       = var.flavor_id
  key_pair        = var.keypair_name
  user_data = data.cloudinit_config.user_data.rendered

  network {
    port = var.network_port.id
  }

  scheduler_hints {
    group = var.server_group.id
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}