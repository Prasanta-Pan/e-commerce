#!/bin/bash
# ============================================================
# scripts/bootstrap-tfstate.sh
#
# Run this script ONCE before the first 'terraform init' to
# create the Azure Storage account that holds Terraform state.
#
# Prerequisites:
#   - Azure CLI installed and logged in ('az login')
#   - Sufficient permissions: Contributor on the target subscription
#
# Usage:
#   chmod +x scripts/bootstrap-tfstate.sh
#   ./scripts/bootstrap-tfstate.sh
#
# Customise the variables below to match your environment.
# ============================================================

set -euo pipefail

# ── Configuration — change these before running ───────────────────────────────
LOCATION="australiaeast"
TFSTATE_RG="tfstate-rg"
TFSTATE_SA="ecommercetfstate"   # Must be globally unique, 3-24 lowercase alphanumeric chars
TFSTATE_CONTAINER="tfstate"
# ──────────────────────────────────────────────────────────────────────────────

echo "==> Creating resource group '${TFSTATE_RG}' in '${LOCATION}'..."
az group create \
  --name "${TFSTATE_RG}" \
  --location "${LOCATION}" \
  --output table

echo "==> Creating storage account '${TFSTATE_SA}'..."
az storage account create \
  --name "${TFSTATE_SA}" \
  --resource-group "${TFSTATE_RG}" \
  --location "${LOCATION}" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --allow-blob-public-access false \
  --min-tls-version "TLS1_2" \
  --output table

echo "==> Enabling versioning on storage account (soft-delete for state history)..."
az storage account blob-service-properties update \
  --account-name "${TFSTATE_SA}" \
  --resource-group "${TFSTATE_RG}" \
  --enable-versioning true \
  --output table

echo "==> Creating blob container '${TFSTATE_CONTAINER}'..."
az storage container create \
  --name "${TFSTATE_CONTAINER}" \
  --account-name "${TFSTATE_SA}" \
  --auth-mode login \
  --output table

echo ""
echo "Bootstrap complete. You can now run:"
echo "  cd infra"
echo "  terraform init"
echo ""
echo "If the storage account name '${TFSTATE_SA}' is already taken globally,"
echo "update the name in both this script and infra/backend.tf, then re-run."
