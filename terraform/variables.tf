# =============================================================
# Variables — Edge Monitoring Infrastructure
# =============================================================

# -------------------------------------------------------------
# OpenStack Authentication
# -------------------------------------------------------------
variable "auth_url" {
  description = "OpenStack Keystone API URL"
  type        = string
}

variable "os_username" {
  description = "OpenStack username"
  type        = string
}

variable "os_password" {
  description = "OpenStack password"
  type        = string
}

variable "os_project_name" {
  description = "OpenStack project name"
  type        = string
}

variable "os_domain_name" {
  description = "OpenStack domain name"
  type        = string
  default     = "Default"
}

# -------------------------------------------------------------
# VM Configuration
# -------------------------------------------------------------
variable "image_name" {
  description = "VM image name"
  type        = string
}

variable "flavor_name" {
  description = "VM flavor name"
  type        = string
}

variable "keypair_name" {
  description = "SSH keypair name"
  type        = string
}

# -------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------
variable "external_network" {
  description = "External network name for router gateway"
  type        = string
}

variable "network_prefix" {
  description = "Prefix for all network resource names"
  type        = string
}

variable "subnet1_cidr" {
  description = "CIDR for subnet1"
  type        = string
  default     = "10.2.1.0/24"
}

variable "subnet1_gateway" {
  description = "Gateway IP for subnet1"
  type        = string
  default     = "10.2.1.1"
}

variable "subnet1_allocation_start" {
  description = "Start of allocation pool for subnet1"
  type        = string
  default     = "10.2.1.10"
}

variable "subnet1_allocation_end" {
  description = "End of allocation pool for subnet1"
  type        = string
  default     = "10.2.1.50"
}

variable "subnet2_cidr" {
  description = "CIDR for subnet2"
  type        = string
  default     = "10.2.2.0/24"
}

variable "subnet2_gateway" {
  description = "Gateway IP for subnet2"
  type        = string
  default     = "10.2.2.1"
}

variable "subnet2_allocation_start" {
  description = "Start of allocation pool for subnet2"
  type        = string
  default     = "10.2.2.10"
}

variable "subnet2_allocation_end" {
  description = "End of allocation pool for subnet2"
  type        = string
  default     = "10.2.2.50"
}
