# =============================================================
# Security Groups — Edge Monitoring Infrastructure
# Allows: SSH, MQTT (1883), Node Exporter (9100), ICMP
# =============================================================

resource "openstack_networking_secgroup_v2" "edge_sg" {
  name        = "${var.network_prefix}-edge-sg"
  description = "Security group for edge monitoring nodes"
}

# SSH access
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# ICMP (ping)
resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# Node Exporter — Prometheus scraping
resource "openstack_networking_secgroup_rule_v2" "node_exporter" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 9100
  port_range_max    = 9100
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# MQTT — sensor data from broker
resource "openstack_networking_secgroup_rule_v2" "mqtt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1883
  port_range_max    = 1883
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# Egress — all outbound traffic allowed
resource "openstack_networking_secgroup_rule_v2" "egress_tcp" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "egress_udp" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}
