terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.51.0"
    }
  }
}
provider "azurerm" {

    client_id       = "5e636370-3b89-4d4a-8742-0cc9346f9308"
    tenant_id       = "be4fe9dc-a5f8-4649-b927-a49592994082"
    subscription_id = "d786964d-240f-4088-9247-4ba08f0c47d0"
    client_secret   = "qJH8Q~Klh5-PcjIslNfFcSi9hsUX2YBjFTlYGbtz"

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

variable "vm_admin_username" {}
variable "vm_admin_password" {}

# RESOURCE GROUP
resource "azurerm_resource_group" "test" {
  name     = "RG-Terraform"
  location = "East US"

  tags = {
    environment = "group-demo"
  }
}

# VIRTUAL NETWORK
resource "azurerm_virtual_network" "VNet" {
  name                = "VNet"
  address_space       = ["192.168.0.0/22"]
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

# SUBNETS
variable "subnet-names" {
  type = list(string)
  default = ["Subnet-Web", "Subnet-App", "Subnet-DB"]
}

resource "azurerm_subnet" "Subnets" {
  count                = length(var.subnet-names)
  name                 = var.subnet-names[count.index]
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.VNet.name
  address_prefixes     = count.index == 0 ? ["192.168.0.0/26"] : count.index == 1 ? ["192.168.0.64/28"] : ["192.168.0.128/25"]
}

#NETWORK INTERFACE 
resource "azurerm_network_interface" "nic" {
  count               = length(var.subnet-names)
  name                = count.index == 0 ? "NIC-Web" : count.index == 1 ? "NIC-App" : "NIC-DB"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name      = "testconfiguration1"
    subnet_id = azurerm_subnet.Subnets[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
}

# CENT OS - VIRTUAL MACHINEs
resource "azurerm_virtual_machine" "AZURE-VM" {
  count                 = length(var.subnet-names)
  name                  = count.index == 0 ? "VM-Web" : count.index == 1 ? "VM-App" : "VM-DB"
  location              = azurerm_resource_group.test.location
  resource_group_name   = azurerm_resource_group.test.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  vm_size               = "Standard_B2s"

  storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "7.5"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }
  os_profile {
    computer_name  = "AZ-EUS-L-WB-WB01-${count.index}"
    admin_username = var.vm_admin_username
    admin_password = var.vm_admin_password
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}
