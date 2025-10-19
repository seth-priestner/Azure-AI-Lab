variable "resource_group_name"      { type = string }
variable "location"                 { type = string }
variable "account_name"             { type = string }  # e.g., "rtai-aoai-abc12"
variable "custom_subdomain_name"    { type = string }  # typically same stem as account name
variable "sku_name"                 { type = string  default = "S0" }
variable "public_network_access_enabled" { type = bool default = false }

variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_id"        { type = string }

variable "deployments" {
  description = "Map of deployment_name => { model_name, model_version, sku_name }"
  type = map(object({
    model_name    = string
    model_version = string
    sku_name      = optional(string, "Standard")
  }))
  default = {}
}

variable "tags" { type = map(string) default = {} }
