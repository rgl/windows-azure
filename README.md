# About

This builds an Azure Windows Image.

This is based on Windows 2022.

# Usage

Install Packer and the Azure CLI.

Login into azure:

```bash
az login
```

List the subscriptions:

```bash
az account list --all
az account show
```

Set the subscription:

```bash
export ARM_SUBSCRIPTION_ID="<YOUR-SUBSCRIPTION-ID>"
az account set --subscription "$ARM_SUBSCRIPTION_ID"
```

Set the secrets:

```bash
cat >secrets.sh <<EOF
export CHECKPOINT_DISABLE='1'
export ARM_SUBSCRIPTION_ID='$ARM_SUBSCRIPTION_ID'
export PKR_VAR_location='northeurope'
export PKR_VAR_resource_group_name='rgl-windows'
export PKR_VAR_image_name='rgl-windows'
export TF_VAR_location="\$PKR_VAR_location"
export TF_VAR_resource_group_name="\$PKR_VAR_resource_group_name"
export TF_VAR_image_name="\$PKR_VAR_image_name"
export TF_LOG='TRACE'
export TF_LOG_PATH='terraform.log'
EOF
```

Create the resource group:

```bash
source secrets.sh
az group create \
    --name "$PKR_VAR_resource_group_name" \
    --location "$PKR_VAR_location"
```

Build the image:

```bash
source secrets.sh
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows.init.log \
    packer init .
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows.log \
    packer build -only=azure-arm.windows -on-error=abort -timestamp-ui .
```

Create the example terraform environment that uses the created image:

```bash
pushd example
terraform init
terraform apply
```

At VM initialization time, the [Azure Windows VM Agent](https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/agent-windows) will run the `example/provision.ps1` script to launch the example application.

After VM initialization is done (check the boot diagnostics serial log for cloud-init entries), test the `app` endpoint:

```bash
wget -qO- "http://$(terraform output --raw app_ip_address)/test"
```

Access using RDP, either using Remmina or FreeRDP:

```bash
remmina --connect "rdp://rgl@$(terraform output --raw app_ip_address)"
xfreerdp "/v:$(terraform output --raw app_ip_address)" /u:rgl /size:1440x900 +clipboard
```

Open a shell inside the VM, using PowerShell Remoting over SSH:

```bash
pwsh
Enter-PSSession -HostName "rgl@$(terraform output --raw app_ip_address)"
$PSVersionTable
whoami /all
docker info
docker ps
docker run --rm hello-world
exit # exit Enter-PSSession.
exit # exit pwsh.
```

Open a shell inside the VM, over SSH:

```bash
ssh "rgl@$(terraform output --raw app_ip_address)"
whoami /all
docker info
docker ps
docker run --rm hello-world
exit
```

Try recreating the VM:

```bash
terraform destroy -target=azurerm_windows_virtual_machine.example
terraform apply
```

Destroy the example terraform environment:

```bash
terraform destroy
popd
```

Destroy the remaining resources (e.g. the image):

```bash
az group delete --name "$PKR_VAR_resource_group_name"
```
