############################################
# Terraform / Provider
############################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Separate backend for UAT
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "lightsail/uat/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

############################################
# Variables
############################################
variable "aws_region" {
  description = "AWS region to deploy into (must support Lightsail)."
  type        = string
  default     = "eu-west-3"
}

variable "ec2_public_key" {
  description = "Public SSH key to import into Lightsail."
  type        = string
}

variable "environment" {
  description = "Environment name (uat)"
  type        = string
  default     = "uat"
}

variable "route53_zone_name" {
  description = "Public hosted zone name (must end with a trailing dot)."
  type        = string
  default     = "lookresto.com."
}

variable "record_name" {
  description = "DNS record to create in Route53 (relative to hosted zone)."
  type        = string
  default     = "uat" # results in uat.lookresto.com
}

variable "availability_zone" {
  description = "Lightsail availability zone (must match aws_region)."
  type        = string
  default     = "eu-west-3a"
}

variable "blueprint_id" {
  description = "Lightsail blueprint (OS image)."
  type        = string
  default     = "ubuntu_22_04"
}

variable "bundle_id" {
  description = "Lightsail bundle (size/price)."
  type        = string
  default     = "medium_2_0"
}

variable "open_tcp_ports" {
  description = "List of TCP ports to open in Lightsail firewall."
  type        = list(number)
  default     = [22, 80, 443, 8080]
}

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.route53_zone_name
  private_zone = false
}

############################################
# Lightsail Key Pair
############################################
resource "aws_lightsail_key_pair" "uat_key" {
  name       = "uat-lightsail-key"
  public_key = var.ec2_public_key
}

############################################
# Lightsail Instance
############################################
resource "aws_lightsail_instance" "uat" {
  name              = "uat-lightsail"
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  key_pair_name     = aws_lightsail_key_pair.uat_key.name

  tags = {
    Environment = "uat"
    ManagedBy   = "terraform"
  }
}

############################################
# Public Firewall (Ports)
############################################
resource "aws_lightsail_instance_public_ports" "uat_fw" {
  instance_name = aws_lightsail_instance.uat.name

  dynamic "port_info" {
    for_each = var.open_tcp_ports
    content {
      protocol  = "tcp"
      from_port = port_info.value
      to_port   = port_info.value
    }
  }
}

############################################
# Static IP
############################################
resource "aws_lightsail_static_ip" "uat_ip" {
  name = "uat-lightsail-ip"
}

resource "aws_lightsail_static_ip_attachment" "uat_ip_attach" {
  static_ip_name = aws_lightsail_static_ip.uat_ip.name
  instance_name  = aws_lightsail_instance.uat.name
}

############################################
# Route 53 DNS (A record -> static IP)
############################################
resource "aws_route53_record" "uat_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.record_name
  type    = "A"
  ttl     = 300
  records = [aws_lightsail_static_ip.uat_ip.ip_address]
}

############################################
# SSM Parameter Store (save public IP)
############################################
resource "aws_ssm_parameter" "lightsail_ip" {
  name  = "/lightsail/uat/ip"
  type  = "String"
  value = aws_lightsail_static_ip.uat_ip.ip_address
  
  tags = {
    Environment = "uat"
    ManagedBy   = "terraform"
  }
}

############################################
# Outputs
############################################
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "lightsail_ip" {
  description = "Lightsail static IP"
  value       = aws_lightsail_static_ip.uat_ip.ip_address
}

output "uat_dns_name" {
  description = "FQDN created in Route53"
  value       = aws_route53_record.uat_dns.fqdn
}

output "instance_name" {
  description = "Lightsail instance name"
  value       = aws_lightsail_instance.uat.name
}
