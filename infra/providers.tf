#configiure the proividers

#aws provider- give credentials
provider "aws" {
  region = var.aws_region
  #if profile is non-empty, use that
  profile = var.aws_profile != "" ? var.aws_profile : null

}

#archive- no credentials, just declare
provider "archive" {}