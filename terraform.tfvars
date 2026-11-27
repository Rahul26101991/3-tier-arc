resource_group_name = "3-tier-arc-rg"
env                 = "test"
vnet                = "3-tier-arc-vnet-01"
location            = "centralindia"
address_space       = ["10.10.0.0/16"]

snet = {
  frontend = {
    name             = "3-tier-arc-snet-01"
    address_prefixes = "10.10.1.0/24"
  }
  backend = {
    name             = "3-tier-arc-snet-02"
    address_prefixes = "10.10.2.0/24"
  }
  database = {
    name             = "3-tier-arc-snet-03"
    address_prefixes = "10.10.3.0/24"
  }
}


nic = {
  frontend = {
    name             = "3-tier-arc-nic-01"
    ip_configuration = "Dynamic"
  }
  backend = {
    name             = "3-tier-arc-nic-02"
    ip_configuration = "Dynamic"
  }
  database = {
    name             = "3-tier-arc-nic-03"
    ip_configuration = "Dynamic"
  }
}

vms = {
  frontend = {
    name                 = "3-tier-arc-vms-01"
    size                 = "Standard_B2s"
    repo_url             = "https://github.com/devopsinsiders/nextops-dashboard.git"
    admin_username       = "azureuser"
    public_key_path      = "~/.ssh/id_rsa.pub"
    app_port             = 80
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts"
    version              = "latest"
  }
  backend = {
    name                 = "3-tier-arc-vms-02"
    size                 = "Standard_B2s"
    repo_url             = "https://github.com/devopsinsiders/nextops-query-service.git"
    admin_username       = "azureuser"
    public_key_path      = "~/.ssh/id_rsa.pub"
    app_port             = 8000
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts"
    version              = "latest"
  }
  database = {
    name                 = "3-tier-arc-vms-03"
    size                 = "Standard_B2s"
    repo_url             = "https://github.com/devopsinsiders/nextops-database.git"
    admin_username       = "azureuser"
    public_key_path      = "~/.ssh/id_rsa.pub"
    app_port             = 5432
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts"
    version              = "latest"
  }
}


nsg_rules = {

  frontend = [
    {
      name                   = "allow-ssh-22"
      priority               = 100
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "22"
      source_address_prefix  = "*"
    },
    {
      name                   = "allow-http-80"
      priority               = 110
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "80"
      source_address_prefix  = "*"
    }
  ]

  backend = [
    {
      name                   = "allow-ssh-22"
      priority               = 100
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "22"
      source_address_prefix  = "*"
    },
    {
      name                   = "allow-api-8000"
      priority               = 110
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "8000"
      source_address_prefix  = "*"
    }
  ]

  database = [
    {
      name                   = "allow-ssh-22"
      priority               = 100
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "22"
      source_address_prefix  = "*"
    },
    {
      name                   = "allow-ssh-5432"
      priority               = 110
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_port_range      = "*"
      destination_port_range = "5432"
      source_address_prefix  = "*"
    }
  ]
}





