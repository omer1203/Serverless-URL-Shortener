#declare variables so you dont have to edit providers file

#AWS region we will be deploying into
variable "aws_region" {
  description = "AWS deploying region"
  type        = string
  default     = "us-east-1"

}

#declare aws profile to use locally
variable "aws_profile" {
  description = "Local AWS CLI profile"
  type        = string
  default     = ""

}

#declare variable name for dynamoDB table
variable "table_name" {
  description = "DynamoDB table for long url"
  type        = string
  default     = "URLShortner"
}