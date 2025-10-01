
resource "aws_s3_bucket" "tf_state" {
  bucket = "my-terraform-uat-state"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "terraform-uat-state"
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "terraform-uat-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "terraform-uat-locks"
  }
}
