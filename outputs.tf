output "public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = module.ec2_instance.public_ip
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = module.ec2_instance.private_ip
}

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.ec2_instance.id
}

output "tags" {
  description = "All tags applied to the EC2 instance."
  value       = module.ec2_instance.tags_all
}

output "private_key" {
  description = "Private SSH key for the EC2 instance."
  value       = module.key_pair.private_key_openssh
  sensitive   = true
}

output "deploy_ssm_document" {
  description = "SSM document for deployment."
  value = {
    name = aws_ssm_document.deploy.name
    arn  = aws_ssm_document.deploy.arn
  }
}

output "security_group_id" {
  description = "Security group ID."
  value       = module.sg.security_group_id
}

output "db_credentials_url_ssm_parameter" {
  description = "SSM parameter name containing database credentials URL."
  value       = aws_ssm_parameter.db_credentials.name
}

output "ec2_env_file_auto_ssm_parameter" {
  description = "SSM parameter name containing auto-generated environment variables."
  value       = aws_ssm_parameter.ec2_env_file_auto.name
}
