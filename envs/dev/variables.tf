variable "prefix"   { type = string  default = "rtai" }
variable "location" { type = string  default = "eastus" }

# AOAI deployments (edit versions to what your region supports)
variable "aoai_deployments" {
  type = map(object({
    model_name    = string
    model_version = string
    sku_name      = optional(string, "Standard")
  }))

  default = {
    "gpt-4o-mini" = {
      model_name    = "gpt-4o-mini"
      model_version = "2024-07-18"
    }
  }
}

variable "enable_request_response_logs" {
  description = "If true, adds RequestResponse category to diagnostics."
  type        = bool
  default     = false
}
