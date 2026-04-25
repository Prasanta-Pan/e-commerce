terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {}
  # Authentication options (in order of precedence):
  #   1. Environment variables: ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
  #   2. Azure CLI: run 'az login' before 'terraform plan/apply'
  #   3. Managed Identity (when running inside Azure, e.g. Azure DevOps hosted agents)
}

provider "azuread" {
  # Uses AZURE_TENANT_ID env var or the tenant from the azurerm provider
}
