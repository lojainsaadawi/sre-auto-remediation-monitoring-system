# =============================================================
# Outputs — Edge Monitoring Infrastructure
# =============================================================

output "edge_node_1_ip" {
  description = "Floating IP of edge-node-1 (zone1)"
  value       = openstack_networking_floatingip_v2.fip_vm1.address
}

output "edge_node_2_ip" {
  description = "Floating IP of edge-node-2 (zone2)"
  value       = openstack_networking_floatingip_v2.fip_vm2.address
}

output "edge_node_3_ip" {
  description = "Reserved floating IP for edge-node-3 (standby)"
  value       = openstack_networking_floatingip_v2.fip_vm3.address
}

output "edge_node_1_private_ip" {
  description = "Private IP of edge-node-1"
  value       = openstack_compute_instance_v2.edge_node_1.network[0].fixed_ip_v4
}

output "edge_node_2_private_ip" {
  description = "Private IP of edge-node-2"
  value       = openstack_compute_instance_v2.edge_node_2.network[0].fixed_ip_v4
}

output "edge_node_3_private_ip" {
  description = "Private IP of edge-node-3 (standby)"
  value       = openstack_compute_instance_v2.edge_node_3.network[0].fixed_ip_v4
}

# -------------------------------------------------------------
# Auto-generate Ansible inventory from Terraform outputs
# -------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible-inventory.tpl", {
    vm1_ip         = openstack_networking_floatingip_v2.fip_vm1.address
    vm2_ip         = openstack_networking_floatingip_v2.fip_vm2.address
    vm3_ip         = openstack_networking_floatingip_v2.fip_vm3.address
    vm1_private_ip = openstack_compute_instance_v2.edge_node_1.network[0].fixed_ip_v4
    vm2_private_ip = openstack_compute_instance_v2.edge_node_2.network[0].fixed_ip_v4
    vm3_private_ip = openstack_compute_instance_v2.edge_node_3.network[0].fixed_ip_v4
    vm1_id         = openstack_compute_instance_v2.edge_node_1.id
    vm2_id         = openstack_compute_instance_v2.edge_node_2.id
    vm3_id         = openstack_compute_instance_v2.edge_node_3.id
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
