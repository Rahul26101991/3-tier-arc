resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}


locals {
  common_tags = {
    environment = var.env
    managed_by  = "terraform"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet
  address_space       = var.address_space
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags
}

resource "azurerm_subnet" "snet" {
  for_each             = var.snet
  name                 = each.value.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.address_prefixes]
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "nic" {
  for_each            = var.nic
  name                = each.value.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "${each.key}-ipconfig"
    subnet_id                     = azurerm_subnet.snet[each.key].id
    private_ip_address_allocation = each.value.ip_configuration
    public_ip_address_id          = contains(keys(azurerm_public_ip.pip), each.key) ? azurerm_public_ip.pip[each.key].id : null
  }
}

resource "azurerm_linux_virtual_machine" "vms" {
  for_each              = var.vms
  name                  = each.value.name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = each.value.size
  admin_username        = each.value.admin_username
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]

  admin_ssh_key {
    username   = each.value.admin_username
    public_key = file(each.value.public_key_path)
  }

  os_disk {
    caching              = each.value.caching
    storage_account_type = each.value.storage_account_type
  }

  source_image_reference {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.sku
    version   = each.value.version
  }

  custom_data = base64encode(
    each.key == "database" ? templatefile("${path.module}/scripts/db_init.tftpl", {
      repo_url    = each.value.repo_url
      db_name     = var.db_name
      db_password = var.db_password
      vnet_cidr   = var.address_space[0]
      }) : each.key == "backend" ? templatefile("${path.module}/scripts/backend_init.tftpl", {
      repo_url    = each.value.repo_url
      db_host     = azurerm_network_interface.nic["database"].ip_configuration[0].private_ip_address
      db_port     = "5432"
      db_name     = var.db_name
      db_password = var.db_password
      app_port    = each.value.app_port
      }) : templatefile("${path.module}/scripts/frontend_init.tftpl", {
      repo_url     = each.value.repo_url
      backend_host = azurerm_public_ip.pip["backend"].ip_address
      backend_port = var.vms["backend"].app_port
    })
  )
}


resource "azurerm_network_security_group" "nsg" {
  for_each            = var.nsg_rules
  name                = "3-tier-arc-nsg-${each.key}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = local.common_tags

  dynamic "security_rule" {
    for_each = each.value
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "snet_nsg" {
  for_each                  = var.snet
  subnet_id                 = azurerm_subnet.snet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}



resource "azurerm_public_ip" "pip" {
  for_each            = toset(["frontend", "backend"])
  name                = "3-tier-arc-pip-${each.key}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}