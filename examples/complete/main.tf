terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for existing infrastructure
data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "public" {
  id = var.subnet_id
}

# S3 bucket for database backups
module "db_backup_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.7.0"

  bucket = "${var.name_prefix}-db-backup"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  attach_require_latest_tls_policy      = true
  attach_deny_insecure_transport_policy = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "1"
      enabled = true
      filter = {
        prefix = ""
      }

      abort_incomplete_multipart_upload_days = 7

      noncurrent_version_transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 60
          storage_class = "ONEZONE_IA"
        }
      ]

      expiration = {
        days = 365
      }

      noncurrent_version_expiration = {
        days = 365
      }
    }
  ]

  versioning = {
    enabled    = true
    mfa_delete = false
  }

  tags = var.tags
}

resource "aws_ssm_parameter" "repo_deploy_key" {
  name  = "/${var.name_prefix}/git/deploy_key"
  type  = "SecureString"
  value = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... (replace with actual key)"
  tags  = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "app_env" {
  name  = "/${var.name_prefix}/app/env"
  type  = "SecureString"
  value = "NODE_ENV=production\nAPI_URL=https://api.example.com"
  tags  = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "docker_env" {
  name  = "/${var.name_prefix}/docker/env"
  type  = "SecureString"
  value = "DOCKER_REGISTRY=your-registry.com"
  tags  = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

# EC2 instance deploy module
module "ec2_instance_deploy" {
  source = "../../"

  name_prefix   = var.name_prefix
  instance_type = var.instance_type

  vpc_config = {
    vpc_id            = data.aws_vpc.main.id
    subnet_id         = data.aws_subnet.public.id
    availability_zone = data.aws_subnet.public.availability_zone
    cidr_block        = data.aws_vpc.main.cidr_block
  }

  database = {
    engine   = var.db_engine
    port     = var.db_engine == "mysql" ? 3306 : 5432
    name     = "${var.name_prefix}_db"
    username = "${var.name_prefix}_user"
  }

  ssm_parameters = {
    repo_deploy_key = aws_ssm_parameter.repo_deploy_key.name
    env_files = [
      aws_ssm_parameter.app_env.name,
      aws_ssm_parameter.docker_env.name
    ]
    additional = []
  }

  deployment = {
    enabled        = true
    git_repository = var.git_repository
    domain_name    = var.domain_name
    ssl_email      = var.letsencrypt_email
  }

  backup = {
    enabled   = true
    s3_bucket = module.db_backup_bucket.s3_bucket_id
    s3_prefix = "backups/"
  }

  ssl_config = {
    enabled              = true
    generate_self_signed = true
    ca_common_name       = "Example CA"
  }

  storage = {
    data_volume = {
      size_gb     = 100
      device_name = "/dev/xvdu"
      mount_point = "/srv"
    }
    backup_volume = {
      size_gb     = 20
      device_name = "/dev/xvdv"
      mount_point = "/backup_tmp"
    }
  }

  tags = var.tags
}
