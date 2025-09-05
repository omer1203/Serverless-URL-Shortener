#declaring the terraform version and provider versions 

terraform {
  required_version = ">= 1.6.0"

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
