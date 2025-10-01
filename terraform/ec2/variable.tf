
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-3"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI for eu-west-3"
  type        = string
  default     = "ami-0809e1e48f650e1f9"
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_public_key" {
  description = "Public SSH key for UAT EC2"
  type        = string
}
