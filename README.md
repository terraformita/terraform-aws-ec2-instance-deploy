# AWS EC2 Instance Deploy Module

This Terraform module creates and configures an EC2 instance for application deployment with database, backup, and SSL capabilities.

## Features

- EC2 instance with EBS volumes for data and backup
- Database setup (MySQL or PostgreSQL)
- SSL certificate generation (self-signed or Let's Encrypt)
- Backup to S3
- Git deployment integration
- SSM parameter management
- Security group configuration

## Usage

### Basic Usage

```hcl
module "ec2_deploy" {
  source = "./terraform-aws-ec2-instance-deploy"

  name_prefix   = "myapp-dev"
  instance_type = "t3.small"

  vpc_config = {
    vpc_id            = "vpc-xxx"
    subnet_id         = "subnet-xxx"
    availability_zone = "us-west-2a"
    cidr_block        = "10.0.0.0/16"
  }

  database = {
    engine   = "mysql"
    port     = 3306
    name     = "myapp"
    username = "myapp_user"
  }

  ssm_parameters = {
    repo_deploy_key = aws_ssm_parameter.deploy_key.name
    env_files = [
      aws_ssm_parameter.app_env.name,
      aws_ssm_parameter.docker_env.name
    ]
    additional = [aws_ssm_parameter.firebase.name]
  }

  deployment = {
    enabled        = true
    git_repository = "git@github.com:user/repo.git"
    domain_name    = "dev.example.com"
    ssl_email      = "admin@example.com"
  }

  backup = {
    enabled   = true
    s3_bucket = aws_s3_bucket.backup.id
    s3_prefix = "backups/"
  }

  ssl_config = {
    enabled              = true
    generate_self_signed = true
    ca_common_name       = "Dev CA"
  }

  storage = {
    data_volume = {
      size_gb     = 50
      device_name = "/dev/xvdu"
      mount_point = "/srv"
    }
    backup_volume = {
      size_gb     = 20
      device_name = "/dev/xvdv"
      mount_point = "/backup_tmp"
    }
  }

  # Optional: Add additional IAM policies for EC2 instance
  iam = {
    additional_policies = [
      data.aws_iam_policy_document.ses_access.json,
      data.aws_iam_policy_document.s3_access.json
    ]
  }

  tags = {
    Environment = "dev"
    Project     = "myapp"
  }
}
```

### Advanced Usage with Additional IAM Policies

You can extend the EC2 instance IAM policy by providing additional policy documents:

```hcl
# Define additional IAM policies
data "aws_iam_policy_document" "ses_access" {
  statement {
    sid    = "SESAccess"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::my-app-bucket/*"]
  }
}

module "ec2_deploy" {
  source = "./terraform-aws-ec2-instance-deploy"

  # ... other configuration ...

  # Add additional IAM policies to the EC2 instance role
  iam = {
    additional_policies = [
      data.aws_iam_policy_document.ses_access.json,
      data.aws_iam_policy_document.s3_access.json
    ]
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| tls | >= 4.0 |
| random | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for resource names. | `string` | n/a | yes |
| instance_type | EC2 instance type. | `string` | `"t3.small"` | no |
| vpc_config | VPC configuration. | `object({vpc_id=string, subnet_id=string, availability_zone=string, cidr_block=optional(string,"")})` | n/a | yes |
| database | Database configuration. | `object({engine=string, port=optional(number,null), name=optional(string,""), username=optional(string,"")})` | n/a | yes |
| ssm_parameters | SSM parameters configuration. | `object({db_credentials=optional(string), repo_deploy_key=string, env_files=list(string), additional=optional(list(string),[])})` | n/a | yes |
| deployment | Deployment configuration. | `object({enabled=optional(bool,true), git_repository=string, domain_name=optional(string,""), ssl_email=optional(string,"")})` | `{enabled=false, git_repository=""}` | no |
| backup | Backup configuration. | `object({enabled=optional(bool,false), s3_bucket=optional(string,""), s3_prefix=optional(string,"backups/")})` | `{enabled=false}` | no |
| ssl_config | SSL certificate configuration. | `object({enabled=optional(bool,true), generate_self_signed=optional(bool,true), ca_common_name=optional(string,"CA")})` | `{enabled=true, generate_self_signed=true}` | no |
| storage | EBS storage configuration. | `object({data_volume=optional(object({...}),{}), backup_volume=optional(object({...}),{})})` | `{}` | no |
| iam | IAM configuration for EC2 instance. | `object({additional_policies=optional(list(string),[])})` | `{additional_policies=[]}` | no |
| tags | Additional tags for resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| public_ip | Public IP address of the EC2 instance. |
| private_ip | Private IP address of the EC2 instance. |
| instance_id | EC2 instance ID. |
| tags | All tags applied to the EC2 instance. |
| private_key | Private SSH key for the EC2 instance. |
| deploy_ssm_document | SSM document for deployment. |
| security_group_id | Security group ID. |
| db_credentials_url_ssm_parameter | SSM parameter name containing database credentials URL. |
| ec2_env_file_auto_ssm_parameter | SSM parameter name containing auto-generated environment variables. |

## Examples

See the [examples](./examples/) directory for complete usage examples.

## License

MIT Licensed. See [LICENSE](LICENSE) for full details.
