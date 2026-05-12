# =============================================================
# Floating IPs
# VM1 and VM2 get floating IPs immediately (always running)
# VM3 gets a floating IP reserved but not associated until
# it is powered on during scale-out
# =============================================================

# VM1 floating IP
resource "openstack_networking_floatingip_v2" "fip_vm1" {
  pool = var.external_network
}

resource "openstack_compute_floatingip_associate_v2" "fip_vm1_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip_vm1.address
  instance_id = openstack_compute_instance_v2.edge_node_1.id
}

# VM2 floating IP
resource "openstack_networking_floatingip_v2" "fip_vm2" {
  pool = var.external_network
}

resource "openstack_compute_floatingip_associate_v2" "fip_vm2_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip_vm2.address
  instance_id = openstack_compute_instance_v2.edge_node_2.id
}

# VM3 floating IP — reserved but not associated
# Association happens in out-scale.yml when VM3 powers on
resource "openstack_networking_floatingip_v2" "fip_vm3" {
  pool = var.external_network
}
