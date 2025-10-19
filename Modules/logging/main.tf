resource "azurerm_log_analytics_workspace" "law" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

# Attach diagnostics to each target
resource "azurerm_monitor_diagnostic_setting" "diag" {
  for_each                   = toset(var.target_resource_ids)
  name                       = "diag-${substr(sha1(each.value), 0, 12)}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  dynamic "log" {
    for_each = var.log_categories
    content {
      category = log.value
      enabled  = true
      retention_policy { enabled = false }
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true
    retention_policy { enabled = false }
  }
}
