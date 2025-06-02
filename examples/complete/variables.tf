variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "example-dev"
}

variable "vpc_id" {
  description = "VPC ID where the instance will be created."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be created."
  type        = string
}

variable "git_repository" {
  description = "The code repo to deploy."
  type        = string
}

variable "domain_name" {
  description = "Route53 and self-signed certificate domain name."
  type        = string
}

variable "letsencrypt_email" {
  description = "Email to issue LetsEncrypt SSL certificates."
  type        = string
}

variable "db_engine" {
  description = "The database engine installed of the instance: either 'mysql' or 'postgres'."
  type        = string
  default     = "mysql"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "tags" {
  description = "Additional tags for resources."
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "example"
  }
}
