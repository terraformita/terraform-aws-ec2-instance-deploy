variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "vpc_config" {
  description = "VPC configuration."
  type = object({
    vpc_id            = string
    subnet_id         = string
    availability_zone = string
    cidr_block        = optional(string, "10.0.0.0/8")
  })
}

variable "database" {
  description = "Database configuration."
  type = object({
    engine   = string
    port     = optional(number, null)
    name     = optional(string, "")
    username = optional(string, "")
  })

  validation {
    condition     = contains(["mysql", "postgres"], var.database.engine)
    error_message = "Database engine must be either 'mysql' or 'postgres'."
  }
}

variable "ssm_parameters" {
  description = "SSM parameters configuration."
  type = object({
    db_credentials  = optional(string)
    repo_deploy_key = string
    env_files       = list(string)
    additional      = optional(list(string), [])
  })
}

variable "deployment" {
  description = "Deployment configuration."
  type = object({
    enabled           = optional(bool, true)
    git_repository    = string
    default_branch    = optional(string, "main")
    domain_name       = optional(string, "")
    ssl_email         = optional(string, "")
    compose_overrides = optional(string, "")
    log_group = optional(object({
      name              = optional(string, "")
      retention_in_days = optional(number, 30)
      encrypted         = optional(bool, true)
      kms_key_arn       = optional(string, "")
    }), {})
  })
  default = {
    enabled           = false
    git_repository    = ""
    default_branch    = "main"
    compose_overrides = ""
    log_group         = {}
  }
}

variable "backup" {
  description = "Backup configuration."
  type = object({
    enabled   = optional(bool, false)
    s3_bucket = optional(string, "")
    s3_prefix = optional(string, "backups/")
  })
  default = {
    enabled = false
  }
}

variable "ssl_config" {
  description = "SSL certificate configuration."
  type = object({
    enabled              = optional(bool, true)
    generate_self_signed = optional(bool, true)
    ca_common_name       = optional(string, "CA")
  })
  default = {
    enabled              = true
    generate_self_signed = true
  }
}

variable "storage" {
  description = "EBS storage configuration."
  type = object({
    data_volume = optional(object({
      size_gb     = optional(number, 50)
      device_name = optional(string, "/dev/xvdu")
      mount_point = optional(string, "/srv")
    }), {})
    backup_volume = optional(object({
      size_gb     = optional(number, 10)
      device_name = optional(string, "/dev/xvdv")
      mount_point = optional(string, "/backup_tmp")
    }), {})
  })
  default = {}
}

variable "tags" {
  description = "Additional tags for resources."
  type        = map(string)
  default     = {}
}

variable "extra_env_vars_auto" {
  description = "Additional key-value map to be appended to the ec2_env_file_auto SSM parameter."
  type        = map(string)
  default     = {}
}

variable "root_block_device" {
  description = "Root block device configuration for the EC2 instance. Tags will be merged with local EC2 instance tags."
  type = object({
    encrypted   = optional(bool, true)
    volume_type = optional(string, "gp3")
    volume_size = optional(number, 25)
    tags        = optional(map(string), {})
  })
  default = {}
}

variable "security_group" {
  description = "Additional ingress and egress config for security group"
  type = object({
    ingress_with_cidr_blocks = optional(list(any), [])
    egress_rules             = optional(list(any), [])
  })
}

variable "iam" {
  description = "IAM configuration for EC2 instance."
  type = object({
    additional_policies = optional(list(string), [])
  })
  default = {
    additional_policies = []
  }
}

variable "docker" {
  description = "Docker daemon configuration."
  type = object({
    # percents from root volume size
    cache_size = optional(number, 80)
  })
  default = {
    cache_size = 80
  }
}
