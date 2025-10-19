resource "random_string" "sfx" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  rg_name     = "${var.prefix}-rg-${random_string.sfx.result}"
  aoai_name   = "${var.prefix}-aoai-${random_string.sfx.result}"
  apim_name   = "${var.prefix}-apim-${random_string.sfx.result}"
  vnet_name   = "${var.prefix}-vnet"
  workspace   = "${var.prefix}-law-${random_string.sfx.result}"
  tags        = { env = "dev", owner = "redteam" }

  diag_categories = var.enable_request_response_logs ? ["Audit","RequestResponse"] : ["Audit"]
}

resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "../../modules/network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  vnet_name           = local.vnet_name
  tags                = local.tags

  # Override CIDRs if you need to
  # address_space = ["10.60.0.0/16"]
  # subnets = { apps="10.60.1.0/24", apim="10.60.2.0/24", priv_endpoints="10.60.3.0/24" }
}

module "openai" {
  source                     = "../../modules/openai"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  account_name               = local.aoai_name
  custom_subdomain_name      = local.aoai_name
  private_endpoint_subnet_id = module.network.subnet_priv_ep_id
  private_dns_zone_id        = module.network.openai_dns_zone_id
  deployments                = var.aoai_deployments
  tags                       = local.tags
}

module "logging" {
  source              = "../../modules/logging"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  workspace_name      = local.workspace
  target_resource_ids = [module.openai.account_id]
  log_categories      = local.diag_categories
  tags                = local.tags
}

module "apim" {
  source              = "../../modules/apim"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  apim_name       = local.apim_name
  publisher_name  = "redteam"
  publisher_email = "ops@example.com"
  sku_name        = "Developer_1"

  apim_subnet_id     = module.network.subnet_apim_id
  aoai_account_id    = module.openai.account_id
  aoai_endpoint_host = "${module.openai.custom_subdomain_name}.openai.azure.com"

  rate_limit_calls   = 300
  rate_limit_seconds = 60

  tags = local.tags
}

# Optional: sample App Service behind VNet to call APIM (add later if you want)
