output "wazuh_instance_id" {
  description = "Target for SSM sessions and the dashboard port forwarding"
  value       = aws_instance.wazuh.id
}

output "development_instance_id" {
  value = module.development.instance_id
}

output "production_instance_id" {
  value = module.production.instance_id
}

output "admin_password_parameter" {
  value = aws_ssm_parameter.admin_password.name
}
