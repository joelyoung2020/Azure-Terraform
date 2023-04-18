terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "azure-project" {
  name     = "azure-project"
  location = "East US"
  tags ={
    enviroment = "dev"
  }
}

resource "azurerm_virtual_network" "azure-network" {
  name                = "project-network"
  location            = azurerm_resource_group.azure-project.location
  resource_group_name = azurerm_resource_group.azure-project.name
   address_space     = ["10.0.1.0/16"]
}

resource "azurerm_subnet" "azure-subnet" {
  name                 = "azure-project-subnet"
  resource_group_name  = azurerm_resource_group.azure-project.name
  virtual_network_name = azurerm_virtual_network.azure-project.name
  address_prefixes     = ["10.0.1.0/24"]
}

 resource "azurerm_network_security_group" "azure-sg" {
  name                = "AzureProjectSecurityGroup1"
  location            = azurerm_resource_group.azure-project.location
  resource_group_name = azurerm_resource_group.azure-project.name
  tags ={
    enviroment = "dev"
  }
 }

 resource "azurerm_network_security_rule" "azure-sg-rule" {
  name                        = "ssh-access"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "22"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.azure-project.name
  network_security_group_name = azurerm_network_security_group.azure-sg.name
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.azure-subnet.id
  network_security_group_id = azurerm_network_security_group.azure-sg.id
}

resource "azurerm_public_ip" "azure-ip" {
  name                = "azure-vm-ipaddress"
  resource_group_name = azurerm_resource_group.azure-project.name
  location            = azurerm_resource_group.azure-project.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "azure-interface" {
  name                = "example-nic"
  location            = azurerm_resource_group.azure-project.location
  resource_group_name = azurerm_resource_group.azure-project.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azure-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.azure-ip.id
  }
}

 resource "azurerm_linux_virtual_machine" "azure-vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.azure-project.name
  location            = azurerm_resource_group.azure-project.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.azure-interface.id,
  ]
  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/azure-vm.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  provisioner "local-exec" {
    command = templatefile(${var.host_os} -ssh-script.tpl, {
        hostname = self.public_ip_address,
        user = "adminuser"
        identifyfile= "~/.ssh/azure -vm"
    })
    interpreter = var.host_os == "linux" ? ["bash", "-c"] : ["Powershell", "-command"]
  }
}

output "public_ip_address" {
  value       =  azurerm_linux_virtual_machine.azure-vm.public_ip_address
  sensitive   = true
  description = "azure vm ip address"
  depends_on  = []
}
