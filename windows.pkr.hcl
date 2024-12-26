packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-azure
    azure = {
      version = "2.2.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "resource_group_name" {
  type    = string
  default = "rgl-windows"
}

variable "image_name" {
  type    = string
  default = "rgl-windows"
}

source "azure-arm" "windows" {
  use_azure_cli_auth = true
  location           = var.location

  vm_size = "Standard_DS1_v2" # 1 vCPU. 3.5 GB RAM.

  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-datacenter-smalldisk-g2" # NB two disk sizes versions are available: 2022-datacenter-g2 (127GB) and 2022-datacenter-smalldisk-g2 (30GB).

  temp_resource_group_name          = "${var.resource_group_name}-tmp"
  managed_image_resource_group_name = var.resource_group_name
  managed_image_name                = var.image_name

  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "5m"
  winrm_username = "packer"

  # provision pwsh and powershell remoting.
  # NB this cannot be done from a provisioner because it reconfigures winrm.
  # NB this script is run as the SYSTEM user.
  # NB this script must execute is less than 90 minutes.
  # NB when this script fails (e.g. exception), the provisioning fails.
  # see https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
  custom_data = base64encode(<<-EOF
  Start-Transcript -Path C:\AzureData\provision.log
  ${file("provision-pwsh.ps1")}
  ${file("provision-psremoting.ps1")}
  EOF
  )
  # NB this is not actually a script. its a single command line to execute.
  custom_script = <<-EOF
  PowerShell -ExecutionPolicy Bypass -NonInteractive -Command "gc -Raw C:\AzureData\CustomData.bin | iex"
  EOF

  azure_tags = {
    owner = "rgl"
  }
}

build {
  sources = [
    "source.azure-arm.windows"
  ]

  provisioner "powershell" {
    scripts = [
      "provision-wait-ready.ps1",
    ]
  }

  provisioner "powershell" {
    inline = [
      <<-EOF
      Write-Host 'Getting the custom_data/custom_script log...'
      Get-Content -Raw C:\AzureData\provision.log
      EOF
    ]
  }

  provisioner "powershell" {
    scripts = [
      "provision-openssh.ps1",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "provision-chocolatey.ps1",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "provision-base.ps1",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "provision-containers-feature.ps1",
    ]
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    scripts = [
      "provision-docker.ps1",
      "provision-docker-compose.ps1",
    ]
  }

  provisioner "powershell" {
    scripts = [
      "provision-generalize.ps1",
    ]
  }
}
