# =============================================================
# Edge Node VM Instances
# VM1: edge-node-1 (zone1) — running   on compute1, net1
# VM2: edge-node-2 (zone2) — running   on compute2, net2
# VM3: edge-node-3 (standby) — SHUTOFF on compute1, net2
#      VM3 is powered on only during emergency scale-out
# =============================================================

data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

data "openstack_compute_keypair_v2" "keypair" {
  name = var.keypair_name
}

# -------------------------------------------------------------
# VM1 — edge-node-1 — Zone 1 — always running
# -------------------------------------------------------------
resource "openstack_compute_instance_v2" "edge_node_1" {
  name              = "edge-node-1"
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = data.openstack_compute_keypair_v2.keypair.name
  security_groups   = [openstack_networking_secgroup_v2.edge_sg.name]
  availability_zone = "nova:compute1"
  power_state       = "active"

  network {
    uuid = openstack_networking_network_v2.net1.id
  }

  metadata = {
    zone = "zone1"
    role = "edge-node"
  }
}

# -------------------------------------------------------------
# VM2 — edge-node-2 — Zone 2 — always running
# -------------------------------------------------------------
resource "openstack_compute_instance_v2" "edge_node_2" {
  name              = "edge-node-2"
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = data.openstack_compute_keypair_v2.keypair.name
  security_groups   = [openstack_networking_secgroup_v2.edge_sg.name]
  availability_zone = "nova:compute2"
  power_state       = "active"

  network {
    uuid = openstack_networking_network_v2.net2.id
  }

  metadata = {
    zone = "zone2"
    role = "edge-node"
  }
}

# -------------------------------------------------------------
# VM3 — edge-node-3 — Standby — POWERED OFF
# Activated only during emergency scale-out via out-scale.yml
# -------------------------------------------------------------
resource "openstack_compute_instance_v2" "edge_node_3" {
  name              = "edge-node-3"
  image_id          = data.openstack_images_image_v2.image.id
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = data.openstack_compute_keypair_v2.keypair.name
  security_groups   = [openstack_networking_secgroup_v2.edge_sg.name]
  availability_zone = "nova:compute1"
  power_state       = "shutoff"

  network {
    uuid = openstack_networking_network_v2.net2.id
  }

  metadata = {
    zone = "standby"
    role = "edge-node-standby"
  }
}
