# Remote state stored in Azure Blob Storage.
# Run scripts/bootstrap-tfstate.sh ONCE to create the storage account,
# then run 'terraform init' to initialise this backend.
#
# Override individual settings at init time with:
#   terraform init -backend-config="storage_account_name=myuniquename"
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "ecommercetfstate" # must be globally unique — change before first init
    container_name       = "tfstate"
    key                  = "ecommerce.terraform.tfstate"
  }
}
