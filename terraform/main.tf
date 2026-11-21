data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "current" {}

locals {
  cidrs = {
    management  = "10.0.0.0/16"
    development = "10.1.0.0/16"
    production  = "10.2.0.0/16"
  }
}

module "network" {
  source = "./modules/network"
  name   = "management"
  cidr   = local.cidrs.management
  az_id  = var.az_id
  region = var.region
}

module "development" {
  source    = "./modules/spoke"
  providers = { aws = aws.development, aws.hub = aws }

  name          = "development"
  cidr          = local.cidrs.development
  az_id         = var.az_id
  region        = var.region
  hub           = module.network
  manager_ip    = aws_instance.wazuh.private_ip
  wazuh_version = var.wazuh_version
}

module "production" {
  source    = "./modules/spoke"
  providers = { aws = aws.production, aws.hub = aws }

  name          = "production"
  cidr          = local.cidrs.production
  az_id         = var.az_id
  region        = var.region
  hub           = module.network
  manager_ip    = aws_instance.wazuh.private_ip
  wazuh_version = var.wazuh_version
}