resource "azurerm_public_ip" "windows-server-pip" {
  name                = "${var.prefix}-windows-server-pip"
  location            = azurerm_resource_group.demo-windows.location
  resource_group_name = azurerm_resource_group.demo-windows.name
  allocation_method   = "Dynamic"
}
resource "azurerm_network_interface" "windows-server-interface" {
  name                = "${var.prefix}-windows-server-interface"
  location            = azurerm_resource_group.demo-windows.location
  resource_group_name = azurerm_resource_group.demo-windows.name

  ip_configuration {
    name                          = "${var.prefix}_windows-server_ip_config"
    subnet_id                     = azurerm_subnet.demo-windows-internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows-server-pip.id
  }
}
resource "azurerm_windows_virtual_machine" "windows-server" {
  name                = "${var.prefix}-win"
  resource_group_name = azurerm_resource_group.demo-windows.name
  location            = azurerm_resource_group.demo-windows.location
  size                = "Standard_B2MS"
  admin_username      = "adminuser"
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.windows-server-interface.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter-with-Containers"
    version   = "latest"
  }
}

# Join windows not to the cluster
resource "azurerm_virtual_machine_extension" "join-rancher" {
  name                 = "${var.prefix}-windows-node-join-rancher"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows-server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    {
        "commandToExecute": ${jsonencode(
  replace(
    rancher2_cluster.cluster.cluster_registration_token.0.windows_node_command,
    "| iex}",
    "--address ${azurerm_windows_virtual_machine.windows-server.public_ip_address} --internal-address ${azurerm_windows_virtual_machine.windows-server.private_ip_address} --worker | iex}",
  )
)}
    }
SETTINGS
}
