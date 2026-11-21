terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.hub]
    }
  }
}

variable "name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "az_id" {
  type = string
}

variable "region" {
  type = string
}

variable "manager_ip" {
  type = string
}

variable "wazuh_version" {
  type = string
}

variable "hub" {
  description = "Management VPC the agent reports to"
  type        = object({ vpc_id = string, cidr = string, private_route_table_id = string })
}

module "network" {
  source = "../network"
  name   = var.name
  cidr   = var.cidr
  az_id  = var.az_id
  region = var.region
}

data "aws_caller_identity" "this" {}

resource "aws_vpc_peering_connection" "this" {
  provider      = aws.hub
  vpc_id        = var.hub.vpc_id
  peer_vpc_id   = module.network.vpc_id
  peer_owner_id = data.aws_caller_identity.this.account_id
  tags          = { Name = "management-${var.name}" }
}

resource "aws_vpc_peering_connection_accepter" "this" {
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  auto_accept               = true
  tags                      = { Name = "management-${var.name}" }
}

resource "aws_route" "to_hub" {
  route_table_id            = module.network.private_route_table_id
  destination_cidr_block    = var.hub.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.this.id
}

resource "aws_route" "from_hub" {
  provider                  = aws.hub
  route_table_id            = var.hub.private_route_table_id
  destination_cidr_block    = var.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.this.id
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "agent" {
  name = "wazuh-agent"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "agent" {
  name = "wazuh-agent"
  role = aws_iam_role.agent.name
}

resource "aws_security_group" "agent" {
  name        = "wazuh-agent"
  description = "No inbound traffic"
  vpc_id      = module.network.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "agent" {
  ami                    = data.aws_ssm_parameter.al2023.insecure_value
  instance_type          = "t3.small"
  subnet_id              = module.network.private_subnet_id
  vpc_security_group_ids = [aws_security_group.agent.id]
  iam_instance_profile   = aws_iam_instance_profile.agent.name

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/../../templates/wazuh-agent.sh.tftpl", {
    manager_ip    = var.manager_ip
    agent_name    = var.name
    wazuh_version = var.wazuh_version
  })

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "${var.name}-workload" }
}

output "instance_id" {
  value = aws_instance.agent.id
}
