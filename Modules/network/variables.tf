variable "resource_group_name" { type = string }
variable "location"           { type = string }
variable "vnet_name"          { type = string }

variable "address_space" {
  type    = list(string)
  default = ["10.50.0.0/16"]
}

variable "subnets" {
  description = "CIDRs for subnets."
  type = object({
    apps           = string
    apim           = string
    priv_endpoints = string
  })
  default = {
    apps           = "10.50.1.0/24"
    apim           = "10.50.2.0/24"
    priv_endpoints = "10.50.3.0/24"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
