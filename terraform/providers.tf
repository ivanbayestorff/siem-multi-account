terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # The bucket comes from the pipeline: terraform init -backend-config="bucket=..."
  backend "s3" {
    key          = "wazuh-siem/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  tags = {
    Project   = "wazuh-siem"
    ManagedBy = "terraform"
  }
}

# Management account (credentials from the GitHub Actions OIDC role)
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

# Member accounts, reached through the role Organizations creates in each account
provider "aws" {
  alias  = "development"
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.development_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "production"
  region = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.production_account_id}:role/OrganizationAccountAccessRole"
  }
  default_tags {
    tags = local.tags
  }
}
