#declaring the terraform version and provider versions 

terraform {
  required_version = ">= 1.6.0"

  # Backend configuration for state management
  # Commented out for local testing - uncomment after setting up S3 bucket
  # backend "s3" {
  #   # These will be provided via backend config or environment variables
  #   # bucket = "your-terraform-state-bucket"
  #   # key    = "urlshortener/terraform.tfstate"
  #   # region = "us-east-1"
  #   # encrypt = true
  #   # dynamodb_table = "terraform-state-lock"
  # }

  #now specify the providers that will be used
  required_providers {
    aws = {
      source  = "hashicorp/aws" #official AWS provider
      version = ">= 4.0.0"
    }
    #archieve provider for "archive file" data source, will zip lambda code filters
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}
