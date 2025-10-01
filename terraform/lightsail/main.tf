
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
}

provider "aws" {
  region = var.aws_region
}

############################################
# Variables (tune as needed)
############################################
variable "aws_region" {
  description = "AWS region to deploy into (must support Lightsail)."
  type        = string
  default     = "eu-west-3"
}

# Reuses your existing workflow secret TF_VAR_ec2_public_key
variable "ec2_public_key" {
  description = "Public SSH key to import into Lightsail."
  type        = string
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

# Lightsail instance settings
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
  description = "Lightsail bundle (size/price). e.g. nano_2_0, micro_2_0, small_2_0, medium_2_0, large_2_0"
  type        = string
  default     = "medium_2_0"
}

# Open inbound TCP ports you need (22/80/443 typical for SSH + web)
variable "open_tcp_ports" {
  description = "List of TCP ports to open in Lightsail firewall."
  type        = list(number)
  default     = [22, 80, 443]
}

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  name         = var.route53_zone_name # trailing dot required
  private_zone = false
}

############################################
# Lightsail Key Pair
############################################
resource "aws_lightsail_key_pair" "uat_key" {
  name       = "${terraform.workspace}-lightsail-key"
  public_key = var.ec2_public_key
}

############################################
# Lightsail Instance
############################################
resource "aws_lightsail_instance" "uat" {
  name              = "${terraform.workspace}-lightsail"
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.bundle_id
  key_pair_name     = aws_lightsail_key_pair.uat_key.name

  # Optional cloud-init to prep the box (comment out if not needed)
  # user_data = <<-EOF
  # #cloud-config
  # package_update: true
  # packages:
  #   - docker.io
  #   - docker-compose
  # runcmd:
  #   - [ sh, -c, "usermod -aG docker ubuntu || true" ]
  #   - [ sh, -c, "systemctl enable --now docker || true" ]
  # EOF
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
  name = "${terraform.workspace}-lightsail-ip"
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
  name    = var.record_name # e.g. "uat"
  type    = "A"
  ttl     = 300
  records = [aws_lightsail_static_ip.uat_ip.ip_address]
}

############################################
# SSM Parameter Store (save public IP)
############################################
resource "aws_ssm_parameter" "uat_ip" {
  name  = "/${terraform.workspace}/lightsail/public_ip"
  type  = "String"
  value = aws_lightsail_static_ip.uat_ip.ip_address
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
