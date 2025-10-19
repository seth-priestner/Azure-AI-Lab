output "resource_group"     { value = azurerm_resource_group.rg.name }
output "openai_endpoint"    { value = module.openai.endpoint }
output "openai_deployments" { value = module.openai.deployment_names }
output "apim_gateway"       { value = module.apim.gateway_url }
output "apim_api_base"      { value = module.apim.api_base_url }
output "log_analytics"      { value = module.logging.workspace_name }
