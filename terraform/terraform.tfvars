# =============================================================
# Terraform Variable Values — Edge Monitoring
# =============================================================

# OpenStack Authentication
auth_url        = "http://10.20.0.2:5000/v3"
os_username     = "edge-tf"
os_password     = "edgepass"
os_project_name = "edge-monitoring"
os_domain_name  = "Default"

# VM Configuration
image_name   = "focal-server-cloudimg-amd64-vnx"
flavor_name  = "m1.smaller"
keypair_name = "edge-key"

# Network Configuration
external_network = "ExtNet"
network_prefix   = "edge"

subnet1_cidr             = "10.2.1.0/24"
subnet1_gateway          = "10.2.1.1"
subnet1_allocation_start = "10.2.1.10"
subnet1_allocation_end   = "10.2.1.50"

subnet2_cidr             = "10.2.2.0/24"
subnet2_gateway          = "10.2.2.1"
subnet2_allocation_start = "10.2.2.10"
subnet2_allocation_end   = "10.2.2.50"
