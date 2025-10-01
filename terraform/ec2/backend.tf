
terraform {
  backend "s3" {
    bucket         = "my-terraform-uat-state"
    key            = "uat/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "terraform-uat-locks"
    encrypt        = true
  }
}
