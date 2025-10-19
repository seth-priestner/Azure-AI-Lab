output "account_id"            { value = azurerm_cognitive_account.aoai.id }
output "account_name"          { value = azurerm_cognitive_account.aoai.name }
output "custom_subdomain_name" { value = azurerm_cognitive_account.aoai.custom_subdomain_name }
output "endpoint"              { value = "https://${azurerm_cognitive_account.aoai.custom_subdomain_name}.openai.azure.com/" }
output "deployment_names"      { value = keys(azurerm_cognitive_deployment.deploy) }
