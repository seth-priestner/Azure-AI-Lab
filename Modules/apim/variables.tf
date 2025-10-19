variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "apim_name"           { type = string }
variable "publisher_name"      { type = string }
variable "publisher_email"     { type = string }
variable "sku_name"            { type = string  default = "Developer_1" }

variable "apim_subnet_id"      { type = string }
variable "aoai_account_id"     { type = string } # for RBAC assignment
variable "aoai_endpoint_host"  { type = string } # e.g., "rtai-aoai-abc12.openai.azure.com"

variable "rate_limit_calls"    { type = number default = 300 }
variable "rate_limit_seconds"  { type = number default = 60 }

variable "tags" { type = map(string) default = {} }
