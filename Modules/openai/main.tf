resource "azurerm_cognitive_account" "aoai" {
  name                               = var.account_name
  location                           = var.location
  resource_group_name                = var.resource_group_name
  kind                               = "OpenAI"
  sku_name                           = var.sku_name
  custom_subdomain_name              = var.custom_subdomain_name
  public_network_access_enabled      = var.public_network_access_enabled
  identity { type = "SystemAssigned" }
  tags = var.tags
}

resource "azurerm_private_endpoint" "aoai" {
  name                = "${var.account_name}-pep"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "aoai-priv-conn"
    private_connection_resource_id = azurerm_cognitive_account.aoai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "oai-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

# Optional: create multiple model deployments
resource "azurerm_cognitive_deployment" "deploy" {
  for_each             = var.deployments
  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.aoai.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name = each.value.sku_name
  }
}
