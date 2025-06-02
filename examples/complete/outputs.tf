output "public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = module.ec2_instance_deploy.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.ec2_instance_deploy.private_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.ec2_instance_deploy.instance_id
}

output "tags" {
  description = "All tags applied to the EC2 instance."
  value       = module.ec2_instance_deploy.tags
}

output "deploy_ssm_document" {
  description = "SSM document for deployment."
  value       = module.ec2_instance_deploy.deploy_ssm_document
}

output "private_key" {
  description = "Private SSH key for the EC2 instance."
  value       = module.ec2_instance_deploy.private_key
  sensitive   = true
}

output "security_group_id" {
  description = "Security group ID."
  value       = module.ec2_instance_deploy.security_group_id
}

output "db_credentials_url_ssm_parameter" {
  description = "SSM parameter name containing database credentials URL."
  value       = module.ec2_instance_deploy.db_credentials_url_ssm_parameter
}

output "ec2_env_file_auto_ssm_parameter" {
  description = "SSM parameter name containing auto-generated environment variables."
  value       = module.ec2_instance_deploy.ec2_env_file_auto_ssm_parameter
}
