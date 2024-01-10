provider "azurerm" {
  features {}
}

provider "tls" {
  # Configuration options
}
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "azurerm_resource_group" "this" {
  name     = "vmss"
  location = "Uk South"
}

resource "azurerm_virtual_network" "this" {
  name                = "network"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = "vmss"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Standard_F2"
  instances           = 1
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.key.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.internal.id
    }
  }
}

resource "azurerm_monitor_autoscale_setting" "this" {
  name                = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.this.id

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }
  }

  profile {
    name = "weekends"

    capacity {
      default = 0
      minimum = 0
      maximum = 0
    }

    recurrence {
      timezone = "UTC"
      days     = ["Saturday", "Sunday"]
      hours    = [13]
      minutes  = [0]
    }
  }


  profile {
    name = jsonencode(
      {
        "for"  = "weekends"
        "name" = "weekends"
      }
    )

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    recurrence {
      timezone = "UTC"
      days     = ["Saturday", "Sunday"]
      hours    = [08]
      minutes  = [0]
    }
  }


  profile {
    name = "weekdays"

    capacity {
      default = 0
      minimum = 0
      maximum = 0
    }

    recurrence {
      timezone = "UTC"
      days = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday"
      ]
      hours   = [19]
      minutes = [0]
    }
  }


  profile {
    name = jsonencode(
      {
        "for"  = "weekdays"
        "name" = "weekdays"
      }
    )

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    recurrence {
      timezone = "UTC"
      days = ["Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
      "Friday"]
      hours   = [08]
      minutes = [30]
    }
  }
}

