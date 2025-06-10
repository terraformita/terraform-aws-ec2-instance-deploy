#### EC2 INSTANCE
locals {
  ami_ssm_parameter = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"

  ignore_ami_changes          = true
  enable_monitoring           = true
  ebs_optimized               = true
  create_eip                  = true
  create_iam_instance_profile = true
  disable_api_termination     = true
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
    http_put_response_hop_limit = 3
  }
  root_block_device = [
    merge(
      var.root_block_device,
      {
        tags = merge(local.ec2_instance_tags, var.root_block_device.tags)
      }
    )
  ]

  name = "${var.name_prefix}-ec2"

  default_ec2_instance_tags = {
    Name = local.name
    Role = local.service_name
    OS   = "al2023"
  }

  ec2_instance_tags = merge(
    local.default_ec2_instance_tags,
    var.tags
  )

  default_db_ports = {
    mysql    = 3306
    postgres = 5432
  }

  default_ssl_certs_dest = {
    mysql    = "/etc/ssl/mysql"
    postgres = "/etc/ssl/postgres"
  }

  service_name   = var.database.engine
  db_port        = var.database.port != null ? var.database.port : local.default_db_ports[var.database.engine]
  ssl_certs_dest = local.default_ssl_certs_dest[var.database.engine]

  storage = {
    data = merge({
      size_gb     = 50
      device_name = "/dev/xvdu"
      mount_point = "/srv"
    }, var.storage.data_volume)

    backup = merge({
      size_gb     = 10
      device_name = "/dev/xvdv"
      mount_point = "/backup_tmp"
    }, var.storage.backup_volume)
  }

  data_device_tag   = "${var.name_prefix}-${local.service_name}-data"
  backup_device_tag = "${var.name_prefix}-${local.service_name}-backup"

  static_private_ip = var.vpc_config.cidr_block != "" ? cidrhost(var.vpc_config.cidr_block, 100) : null
  private_ip        = local.static_private_ip
  public_ip         = module.ec2_instance.public_ip

  database = {
    name     = var.database.name != "" ? var.database.name : replace(var.name_prefix, "-", "_")
    username = var.database.username != "" ? var.database.username : replace(var.name_prefix, "-", "_")
    password = random_password.db_admin.result
    port     = local.db_port
    host     = local.static_private_ip
  }

  db_credentials = format("%s://%s:%s@%s:%s/%s", local.service_name, local.database.username, local.database.password, local.database.host, local.database.port, local.database.name)
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.vpc_config.availability_zone
  size              = local.storage.data.size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(
    var.tags,
    {
      Name            = format("%s-%s-%d", local.data_device_tag, var.vpc_config.availability_zone, 0)
      VolumeIndex     = 0
      AutoAttachGroup = local.service_name
      Service         = "${local.service_name}-data"
      Snapshot        = "true"
    }
  )
}

resource "aws_ebs_volume" "backup_tmp" {
  availability_zone = var.vpc_config.availability_zone
  size              = local.storage.backup.size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(
    var.tags,
    {
      Name            = format("%s-%s-%d", local.backup_device_tag, var.vpc_config.availability_zone, 0)
      VolumeIndex     = 0
      AutoAttachGroup = local.service_name
      Service         = "${local.service_name}-backup"
      Snapshot        = "true"
    }
  )
}

module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "2.0.3"

  key_name           = "${var.name_prefix}-keypair"
  create_private_key = true
}

module "sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  name        = "${local.name}-sg"
  description = "Security Group for EC2 Instance Egress"

  vpc_id = var.vpc_config.vpc_id

  ingress_with_cidr_blocks = [
    {
      description = "Expose SSH to the Internet"
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Expose HTTP to the Internet"
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Expose HTTPS to the Internet"
      rule        = "https-443-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      description = "Allow access to ${local.service_name} on port ${local.db_port} from the VPC address space"
      from_port   = local.db_port
      to_port     = local.db_port
      protocol    = "tcp"
      cidr_blocks = var.vpc_config.cidr_block != "" ? var.vpc_config.cidr_block : "10.0.0.0/8"
    }
  ]

  egress_rules = [
    "https-443-tcp",
    "ssh-tcp"
  ]

  tags = var.tags
}

resource "random_password" "db_admin" {
  length  = 32
  special = false
  lower   = true
  upper   = true
  numeric = true
  keepers = {
    locked = true
  }
}

resource "tls_private_key" "ca" {
  count = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  count = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? 1 : 0

  private_key_pem = tls_private_key.ca[0].private_key_pem

  subject {
    common_name = var.ssl_config.ca_common_name
  }

  validity_period_hours = 24 * 365 * 10
  early_renewal_hours   = 24 * 31 * 4

  is_ca_certificate = true

  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}

resource "tls_private_key" "server" {
  count = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  count = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? 1 : 0

  private_key_pem = tls_private_key.server[0].private_key_pem
  dns_names       = var.deployment.domain_name != "" ? [var.deployment.domain_name] : []
  ip_addresses = compact([
    local.static_private_ip,
    local.public_ip
  ])

  subject {
    common_name = var.deployment.domain_name != "" ? var.deployment.domain_name : "localhost"
  }
}

resource "tls_locally_signed_cert" "server" {
  count = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? 1 : 0

  cert_request_pem   = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 24 * 365 * 10
  early_renewal_hours   = 24 * 31 * 4

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

locals {
  ssl_certs_keys = [
    "ca.pem",
    "server-cert.pem",
    "server-key.pem"
  ]

  ssl_certs_values = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? [
    tls_self_signed_cert.ca[0].cert_pem,
    tls_locally_signed_cert.server[0].cert_pem,
    tls_private_key.server[0].private_key_pem
  ] : []

  ssl_certs = var.ssl_config.enabled && var.ssl_config.generate_self_signed ? zipmap(local.ssl_certs_keys, local.ssl_certs_values) : {}
}

resource "aws_ssm_parameter" "ssl_certs" {
  for_each = local.ssl_certs

  name  = "/${var.name_prefix}/ec2/${each.key}"
  type  = "SecureString"
  value = each.value
}

data "aws_ssm_parameter" "repo_deploy_key" {
  name = var.ssm_parameters.repo_deploy_key
}

resource "aws_ssm_parameter" "db_credentials" {
  name  = "/${var.name_prefix}/DATABASE_CREDENTIALS_URL"
  type  = "SecureString"
  value = local.db_credentials

  tags = var.tags
}

locals {
  replacements = {
    "{db_url}"      = local.db_credentials
    "{domain_name}" = var.deployment.domain_name
  }

  # Replaces all placeholders like {db_url} in each extra env var value.
  # Uses a predefined map of replacements to substitute the placeholders.
  # Outputs final KEY=value strings for use in the SSM parameter content.
  # Example:
  # { "BASE_URL" = "{domain_name}" } → { "{domain_name}" = var.deployment.domain_name } → { "BASE_URL" = "http://example.com" }
  resolved_extra_env_vars_auto = {
    for key, raw_val in var.extra_env_vars_auto : key => (
      element([
        for i in range(length(local.replacements)) : (
          replace(
            i == 0 ? raw_val : replace(
              raw_val,
              element(keys(local.replacements), 0),
              element(values(local.replacements), 0)
            ),
            element(keys(local.replacements), i),
            element(values(local.replacements), i)
          )
        )
      ], length(local.replacements) - 1)
    )
  }

  extra_env_vars_auto = join("\n", [
    for k, v in local.resolved_extra_env_vars_auto : "${k}=\"${v}\""
  ])
}

resource "aws_ssm_parameter" "ec2_env_file_auto" {
  name  = "/${var.name_prefix}/ec2/env_file_auto"
  type  = "SecureString"
  value = <<EOF
DOMAIN="${var.deployment.domain_name}"
EMAIL="${var.deployment.ssl_email}"
DB_CREDENTIALS="${local.db_credentials}"
${local.extra_env_vars_auto}
EOF

  tags = var.tags
}

locals {
  ssm_params = concat(
    var.ssm_parameters.env_files,
    var.ssm_parameters.additional
  )
}

data "aws_ssm_parameter" "params" {
  for_each = toset(local.ssm_params)
  name     = each.value
}

locals {
  # Collects all relevant SSM parameter ARNs used in the module
  all_ssm_parameters = concat(
    var.ssl_config.enabled ? [for k in local.ssl_certs_keys : aws_ssm_parameter.ssl_certs[k].arn] : [],
    [
      data.aws_ssm_parameter.repo_deploy_key.arn,
      aws_ssm_parameter.db_credentials.arn,
      aws_ssm_parameter.ec2_env_file_auto.arn
    ],
    [for param in data.aws_ssm_parameter.params : param.arn]
  )
}

resource "aws_iam_policy" "ec2_instance" {
  name        = local.name
  description = "Policy for ${local.service_name} instance with EC2 permissions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRRead"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ],
        Resource = ["*"]
      },
      {
        Sid    = "DescribeTags"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:AttachVolume",
          "ec2:DescribeTags",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = ["*"]
      },
      {
        Sid      = "ReadSSMParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.all_ssm_parameters
      },
      var.backup.enabled ? {
        Sid      = "ListBackupBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.backup.s3_bucket}"]
      } : null,
      var.backup.enabled ? {
        Sid    = "RWDBBackupBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:GetObjectAcl"
        ]
        Resource = ["arn:aws:s3:::${var.backup.s3_bucket}/*"]
      } : null
    ]
  })
}

resource "aws_ssm_document" "deploy" {
  name            = "RunDeploy"
  document_type   = "Command"
  document_format = "YAML"

  content = <<EOF
schemaVersion: "2.2"
description: "Deploy code from git repo"
parameters:
  CommitHash:
    description: "Optional Git commit hash to checkout (fallback to main if not set)"
    default: ""
    type: String
mainSteps:
  - action: "aws:runShellScript"
    name: "RunDeploy"
    inputs:
      runCommand:
        - |
          export COMMIT_HASH={{ CommitHash }}
          /opt/scripts/deploy-app-in-docker.sh
EOF
}

locals {
  cloud_init = base64gzip(
    templatefile("${path.module}/user_data/cloud_config.${var.database.engine}.yaml",
      {
        data_device_name    = local.storage.data.device_name
        data_service_name   = "${local.service_name}-data"
        data_mountpoint     = local.storage.data.mount_point
        backup_device_name  = local.storage.backup.device_name
        backup_service_name = "${local.service_name}-backup"
        backup_mountpoint   = local.storage.backup.mount_point

        stage              = var.name_prefix
        service_name       = local.service_name
        ssm_db_credentials = aws_ssm_parameter.db_credentials.name
        db_name            = local.database.name
        db_username        = local.database.username
        db_allowed_network = var.vpc_config.cidr_block != "" ? var.vpc_config.cidr_block : "10.0.0.0/8"
        db_backup_bucket   = var.backup.s3_bucket
        db_backup_dir      = local.storage.backup.mount_point
        db_backup_user     = local.service_name
        db_port            = local.db_port

        git_repository      = var.deployment.git_repository
        ssm_repo_deploy_key = var.ssm_parameters.repo_deploy_key
        ssm_env_files       = join(" ", concat(var.ssm_parameters.env_files, [aws_ssm_parameter.ec2_env_file_auto.name]))

        ssl_certs            = var.ssl_config.enabled ? join(" ", local.ssl_certs_keys) : ""
        ssl_certs_ssm_prefix = "/${var.name_prefix}/ec2"
        ssl_certs_dest       = local.ssl_certs_dest
      }
    )
  )
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name = local.name

  instance_type      = var.instance_type
  key_name           = module.key_pair.key_pair_name
  ami_ssm_parameter  = local.ami_ssm_parameter
  ignore_ami_changes = local.ignore_ami_changes

  subnet_id              = var.vpc_config.subnet_id
  vpc_security_group_ids = [module.sg.security_group_id]

  create_eip                  = local.create_eip
  create_iam_instance_profile = local.create_iam_instance_profile
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    CloudWatchAgentServerPolicy  = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    EC2Policy                    = aws_iam_policy.ec2_instance.arn
  }

  ebs_optimized     = local.ebs_optimized
  root_block_device = local.root_block_device

  enable_volume_tags          = false
  user_data_replace_on_change = true

  monitoring              = local.enable_monitoring
  metadata_options        = local.metadata_options
  disable_api_termination = local.disable_api_termination

  private_ip       = local.private_ip
  user_data_base64 = local.cloud_init

  tags = local.ec2_instance_tags
}
