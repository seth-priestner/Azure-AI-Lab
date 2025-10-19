output "vnet_id"             { value = azurerm_virtual_network.vnet.id }
output "subnet_apps_id"      { value = azurerm_subnet.apps.id }
output "subnet_apim_id"      { value = azurerm_subnet.apim.id }
output "subnet_priv_ep_id"   { value = azurerm_subnet.priv_endpoints.id }
output "openai_dns_zone_id"  { value = azurerm_private_dns_zone.openai.id }
output "openai_dns_zone_name"{ value = azurerm_private_dns_zone.openai.name }
