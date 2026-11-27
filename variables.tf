variable "resource_group_name" {
  type        = string
  description = "name of resource group"
}

variable "env" {
  type        = string
  description = "envrionment"
}

variable "vnet" {
  type        = string
  description = "name of vnet"
}

variable "address_space" {
  type        = list(string)
  description = "details of address space"
}

variable "location" {
  type        = string
  description = "name of location"
}

variable "snet" {
  type = map(object({
    name             = string
    address_prefixes = string
  }))

  description = "details of subnets"
}

variable "nic" {
  type = map(object({
    name             = string
    ip_configuration = string
  }))
  description = "details of nic"
}

variable "vms" {
  type = map(object({
    name                 = string
    size                 = string
    admin_username       = string
    public_key_path      = string
    repo_url             = string
    app_port             = number
    caching              = string
    storage_account_type = string
    publisher            = string
    offer                = string
    sku                  = string
    version              = string
  }))
}


variable "nsg_rules" {
  type = map(list(object({
    name                   = string
    priority               = number
    direction              = string
    access                 = string
    protocol               = string
    source_port_range      = string
    destination_port_range = string
    source_address_prefix  = string
  })))
}



variable "db_name" {
  type        = string
  default     = "nextops"
  description = "PGSQL DB name"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "PGSQL postgres user password"
}

