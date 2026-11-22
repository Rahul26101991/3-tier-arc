resource "azurerm_resource_group" "rg" {
  name     = "var.resource_group_name"
  location = "var.location"
  tags     = local__common_tags
}

locals {
  common_tags = {
    environment = var.env
    managed_by  = "terraform"
  }

  subnet = [
    for snet, name in var.subnet_names : {
      name   = "${var.env}-${name}-subnet"
      prefix = cidrsubnet(var.vnet_cidr, 8, snet)
    }
  ]

   ip_config = [
    for idx, name in var.ip_config : {
      name                          = "${var.env}-${name}-ip_config"
      subnet_id                     = azurerm_subnet.subnet.id
      private_ip_address_allocation = "var.private_ip_address_allocation"
    }
  ]
}



resource "azurerm_virtual_network" "vnet" {
  name                = "var.virtual_network_name"
  address_space       = "var.address_space"
  location            = "var.location"
  resource_group_name = "var.resource_group_name"

  dynamic "subnet" {
    for_each = local.subnet
    content {
      name             = subnet.value.name
      address_prefixes = [subnet.value.prefix]
    }
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "var.network_interface_name"
  location            = "var.location"
  resource_group_name = "var.resource_group_name"

  dynamic "ip_configuration" {
    for_each = local.ip_config
    content {
      name                          = "var.ip_config_name"
      subnet_id                     = azurerm_subnet.subnet.id
      private_ip_address_allocation = "Dynamic"
    }
  }


}







resource "azurerm_linux_virtual_machine" "linux" {

}