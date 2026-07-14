# ---------------------------------------------------------------------------
# Jumpbox: Windows VM reachable only via Azure Bastion. Use it to open the
# Foundry portal / call the private account endpoint and create agents, since
# the account has publicNetworkAccess = Disabled.
# ---------------------------------------------------------------------------

# Dedicated subnet for the jumpbox VM.
resource "azurerm_subnet" "jumpbox" {
  count                = var.enable_jumpbox ? 1 : 0
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.jumpbox_subnet_prefix]
}

# Azure Bastion requires a subnet named exactly "AzureBastionSubnet".
resource "azurerm_subnet" "bastion" {
  count                = var.enable_jumpbox ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_jumpbox ? 1 : 0
  name                = "bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  count               = var.enable_jumpbox ? 1 : 0
  name                = "spoke-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

resource "azurerm_network_interface" "jumpbox" {
  count               = var.enable_jumpbox ? 1 : 0
  name                = "jumpbox-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumpbox" {
  count               = var.enable_jumpbox ? 1 : 0
  name                = "jumpbox-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  size                = var.jumpbox_vm_size
  admin_username      = var.jumpbox_admin_username
  admin_password      = var.jumpbox_admin_password

  network_interface_ids = [azurerm_network_interface.jumpbox[0].id]

  # System-assigned identity used by DefaultAzureCredential on the VM to
  # authenticate to the Foundry account (see Foundry User role in rbac.tf).
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }
}
