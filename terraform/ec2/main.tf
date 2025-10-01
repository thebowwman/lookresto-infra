erraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

# --- Data sources ---
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Fetch hosted zone for Route 53
data "aws_route53_zone" "main" {
  name         = "lookresto.com."   # <-- replace with your domain (trailing dot required)
  private_zone = false
}

# --- Key Pair ---
resource "aws_key_pair" "uat_key" {
  key_name   = "${terraform.workspace}-ec2-key"
  public_key = var.ec2_public_key
}

# --- Security Group ---
resource "aws_security_group" "ec2_sg" {
  name        = "${terraform.workspace}-ec2-sg"
  description = "Allow SSH and HTTP inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ Replace with your IP in production
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- EC2 Instance ---
resource "aws_instance" "uat_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.uat_key.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "${terraform.workspace}-ec2"
  }
}

# --- Route 53 Record pointing to ephemeral IP ---
resource "aws_route53_record" "uat_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "uat.lookresto.com"   # <-- replace with subdomain or root
  type    = "A"
  ttl     = 300
  records = [aws_instance.uat_ec2.public_ip]
}

# --- Save IP in SSM Parameter Store ---
resource "aws_ssm_parameter" "uat_ip" {
  name  = "/${terraform.workspace}/ec2/public_ip"
  type  = "String"
  value = aws_instance.uat_ec2.public_ip
}

# --- Outputs ---
output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.uat_ec2.public_ip
}

output "uat_dns_name" {
  description = "Domain name pointing to EC2"
  value       = aws_route53_record.uat_dns.fqdn
}
