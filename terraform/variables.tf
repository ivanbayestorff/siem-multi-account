variable "region" {
  type    = string
  default = "us-east-1"
}

variable "development_account_id" {
  type      = string
  sensitive = true
}

variable "production_account_id" {
  type      = string
  sensitive = true
}

variable "alert_email" {
  description = "Receives the alerts of the custom detection rules"
  type        = string
  sensitive   = true
}

variable "az_id" {
  description = "Same physical AZ in every account, so peering traffic stays inside one AZ"
  type        = string
  default     = "use1-az1"
}

variable "wazuh_version" {
  description = "Agent version; the server installs the latest patch of the same minor"
  type        = string
  default     = "4.14.10"
}
