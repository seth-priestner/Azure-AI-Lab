resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity { type = "SystemAssigned" }

  # VNet integration so APIM can reach private endpoints
  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = var.apim_subnet_id
  }

  tags = var.tags
}

# Give APIM managed identity access to call Azure OpenAI via AAD
resource "azurerm_role_assignment" "apim_openai_user" {
  scope                = var.aoai_account_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_api_management.apim.identity[0].principal_id
}

# Simple pass-through API that forwards all POSTs to Azure OpenAI
resource "azurerm_api_management_api" "aoai_proxy" {
  name                = "aoai-proxy"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.apim.name

  revision            = "1"
  display_name        = "Azure OpenAI Proxy"
  path                = "aoai"
  protocols           = ["https"]
  api_type            = "http"
  subscription_required = false

  # Point to AOAI custom subdomain; APIM forwards incoming path
  service_url = "https://${var.aoai_endpoint_host}"
}

# Wildcard operation to allow any POST path under /aoai/*
resource "azurerm_api_management_api_operation" "wildcard" {
  operation_id        = "wildcard"
  api_name            = azurerm_api_management_api.aoai_proxy.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name

  display_name = "Wildcard POST"
  method       = "POST"
  url_template = "/*"
}

# API-level policy: require operator header, rate limit, and use APIM's MSI to call AOAI
resource "azurerm_api_management_api_policy" "policy" {
  api_name            = azurerm_api_management_api.aoai_proxy.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policy.xml.tftpl", {
    rate_limit_calls   = var.rate_limit_calls
    rate_limit_seconds = var.rate_limit_seconds
  })
}

output "gateway_url"   { value = azurerm_api_management.apim.gateway_url }
output "api_base_url"  { value = "${azurerm_api_management.apim.gateway_url}/aoai" }
output "principal_id"  { value = azurerm_api_management.apim.identity[0].principal_id }
