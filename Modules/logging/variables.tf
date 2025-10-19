variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "workspace_name"      { type = string }
variable "retention_in_days"   { type = number default = 30 }

variable "target_resource_ids" {
  description = "Resources to attach diagnostic settings to."
  type        = list(string)
  default     = []
}

variable "log_categories" {
  description = "Diagnostic log categories to enable."
  type        = list(string)
  default     = ["Audit"] # add "RequestResponse" in your tfvars if available in your tenant
}

variable "tags" { type = map(string) default = {} }
