# Complete Example

This example demonstrates how to use the EC2 Instance Deploy module with all required infrastructure.

## Usage

1. Set the required variables:

```bash
export TF_VAR_vpc_id="vpc-12345678"
export TF_VAR_subnet_id="subnet-12345678"
export TF_VAR_git_repository="git@github.com:user/repo.git"
export TF_VAR_domain_name="dev.example.com"
export TF_VAR_letsencrypt_email="admin@example.com"
export TF_VAR_name_prefix="myapp-dev"
```

2. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

## What this example creates

- S3 bucket for database backups with encryption and public access blocking
- SSM parameters for Git deploy key and application environment variables
- EC2 instance with MySQL/PostgreSQL database configured for deployment
- All necessary IAM roles and security groups
- EBS volumes for data and backup storage
- SSL certificates (self-signed or Let's Encrypt)

## Outputs

After applying, you'll get:
- Public and private IP addresses of the instance
- Instance ID and security group ID
- SSM parameter names for database credentials and environment files
- SSM document for deployment
- Private SSH key (sensitive output)

## Cleanup

```bash
terraform destroy
```
