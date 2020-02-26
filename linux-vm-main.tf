#####################################
## Linux VM with Web Server - Main ##
#####################################

# Generate random password
resource "random_password" "web-linux-vm-password" {
  length           = 16
  min_upper        = 2
  min_lower        = 2
  min_special      = 2
  number           = true
  special          = true
  override_special = "!@#$%&"
}

# Generate randon name for virtual machine
resource "random_string" "random-linux-vm" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  number  = true
}

# Create Security Group to access web
resource "azurerm_network_security_group" "web-linux-vm-nsg" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "${lower(replace(var.app_name," ","-"))}-${var.environment}-web-linux-vm-nsg"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name

  security_rule {
    name                       = "allow-ssh"
    description                = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    description                = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = {
    environment = var.environment
  }
}

# Associate the web NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "web-linux-vm-nsg-association" {
  depends_on=[azurerm_network_security_group.web-linux-vm-nsg]

  subnet_id                 = azurerm_subnet.network-subnet.id
  network_security_group_id = azurerm_network_security_group.web-linux-vm-nsg.id
}

# Get a Static Public IP
resource "azurerm_public_ip" "web-linux-vm-ip" {
  depends_on=[azurerm_resource_group.network-rg]

  name                = "linux-${random_string.random-linux-vm.result}-vm-ip"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  allocation_method   = "Static"
  
  tags = { 
    environment = var.environment
  }
}

# Create Network Card for web VM
resource "azurerm_network_interface" "web-linux-vm-nic" {
  depends_on=[azurerm_public_ip.web-linux-vm-ip]

  name                = "linux-${random_string.random-linux-vm.result}-vm-nic"
  location            = azurerm_resource_group.network-rg.location
  resource_group_name = azurerm_resource_group.network-rg.name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.network-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web-linux-vm-ip.id
  }

  tags = { 
    environment = var.environment
  }
}

# Create Linux VM with web server
resource "azurerm_virtual_machine" "web-linux-vm" {
  depends_on=[azurerm_network_interface.web-linux-vm-nic]

  location              = azurerm_resource_group.network-rg.location
  resource_group_name   = azurerm_resource_group.network-rg.name
  name                  = "linux-${random_string.random-linux-vm.result}-vm"
  network_interface_ids = [azurerm_network_interface.web-linux-vm-nic.id]
  vm_size               = var.web-linux-vm-size
  license_type          = var.web-linux-license-type

  delete_os_disk_on_termination    = var.web-linux-delete-os-disk-on-termination
  delete_data_disks_on_termination = var.web-linux-delete-data-disks-on-termination

  storage_image_reference {
    id        = lookup(var.web-linux-vm-image, "id", null)
    offer     = lookup(var.web-linux-vm-image, "offer", null)
    publisher = lookup(var.web-linux-vm-image, "publisher", null)
    sku       = lookup(var.web-linux-vm-image, "sku", null)
    version   = lookup(var.web-linux-vm-image, "version", null)
  }

  storage_os_disk {
    name              = "linux-${random_string.random-linux-vm.result}-vm-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "linux-${random_string.random-linux-vm.result}-vm"
    admin_username = var.web-linux-admin-username
    admin_password = random_password.web-linux-vm-password.result
    custom_data    = file("azure-user-data.sh")
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = var.environment
  }
}