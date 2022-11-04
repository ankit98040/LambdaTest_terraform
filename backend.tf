terraform {
  backend "s3" {
    bucket         = "unique-bucket-name-ankit"
    key            = "ecs_environment/terraform.tfstate"
    encrypt        = true
    kms_key_id     = "THE_ID_OF_THE_KMS_KEY"
    region         = "us-east-1"
  }
}
