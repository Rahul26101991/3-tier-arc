output "frontend_public_ip" {
  value = azurerm_public_ip.pip["frontend"].ip_address
}

output "backend_public_ip" {
  value = azurerm_public_ip.pip["backend"].ip_address
}

output "database_private_ip" {
  value = azurerm_network_interface.nic["database"].ip_configuration[0].private_ip_address
}