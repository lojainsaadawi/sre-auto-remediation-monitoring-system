# =============================================================
# Network Resources — Edge Monitoring Infrastructure
# =============================================================

# External network data source
data "openstack_networking_network_v2" "external" {
  name = var.external_network
}

# -------------------------------------------------------------
# Network 1 — for edge-node-1 (zone1)
# -------------------------------------------------------------
resource "openstack_networking_network_v2" "net1" {
  name           = "${var.network_prefix}-net1"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet1" {
  name            = "${var.network_prefix}-subnet1"
  network_id      = openstack_networking_network_v2.net1.id
  cidr            = var.subnet1_cidr
  gateway_ip      = var.subnet1_gateway
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  allocation_pool {
    start = var.subnet1_allocation_start
    end   = var.subnet1_allocation_end
  }
}

# -------------------------------------------------------------
# Network 2 — for edge-node-2 (zone2) and edge-node-3 (standby)
# -------------------------------------------------------------
resource "openstack_networking_network_v2" "net2" {
  name           = "${var.network_prefix}-net2"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "subnet2" {
  name            = "${var.network_prefix}-subnet2"
  network_id      = openstack_networking_network_v2.net2.id
  cidr            = var.subnet2_cidr
  gateway_ip      = var.subnet2_gateway
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  allocation_pool {
    start = var.subnet2_allocation_start
    end   = var.subnet2_allocation_end
  }
}

# -------------------------------------------------------------
# Router — connects both networks to external
# -------------------------------------------------------------
resource "openstack_networking_router_v2" "router" {
  name                = "${var.network_prefix}-router"
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "iface1" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet1.id
}

resource "openstack_networking_router_interface_v2" "iface2" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet2.id
}
