terraform {
  backend "s3" {
    bucket   = "eksprojbackendvenkaiah"
    key      = "statefile/terraform.tfstate"
    region   = "ap-south-1"
    aws_dynamodb_table = "statelock"
    encrypt = "true"
  }
}