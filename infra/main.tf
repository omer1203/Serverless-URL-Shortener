#All Resources will be added here
#lamda, dynamodb, api

resource "aws_dynamodb_table" "url" {
  name         = var.table_name #the actual table name in AWS
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code" #partition key to store items, {short_code: "abc12de", long_url: "https//..."}

  #define the short code
  attribute {
    name = "short_code"
    type = "S" #S means string
  }

  tags = {
    Project = "serverless-url-shortner"
    Env     = "dev"
  }

}


#terraform data source producing zip from a folder
data "archive_file" "shortener_zip" {
  type        = "zip"                                #since it is a zip archive
  source_dir  = "${path.module}/lambda/shortener"    #the folder to zip 
  output_path = "${path.module}/build/shortener.zip" #path where to write the zip- in build since we gitignore the build folder
}

#creating a least priveledge IAM role for the funcitoning lambda
resource "aws_iam_role" "shortener_role" {
  name = "urlshortener-shortener-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "allow",
      Principal = {
        Service = "lambda.amazonaws.com" #lambda service can assuem this role
      },
      Action = "sts:AssumeRole"
    }]
  })
}

#minimal perms to write logs to cloudWatch which is req for lambda, did not add dynamodb put get perms yet
resource "aws_iam_role_policy" "shortener_basic" {
  name = "urlshortener-shortener-basic"
  role = aws_iam_role.shortener_role.id #attaching the role to the policy

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "AllowCreateWriteLogs",
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}


#now def the lambda function recourse
resource "aws_lambda_function" "shortener" {
  function_name = "urlshortner-shortener"
  role          = aws_iam_role.shortener_role.arn #attaching the role to the lambda func

  #runtime and handler tells lambda how to run code handler.py to lambda_handler
  runtime = "python3.11"             #the runtime for the lambda func
  handler = "handler.lambda_handler" #the entry point for the lambda func

  #filename will be the zip created by archive_file
  filename         = data.archive_file.shortener_zip.output_path         #the zip file to upload to lambda
  source_code_hash = data.archive_file.shortener_zip.output_base64sha256 #the hash of the zip file to ensure the lambda func is updated when the zip changes
  #source code hash forces AWS to update code when zip changes

  timeout       = 5         #5 sec, short but enough got small logic
  memory_size   = 256       #mb, also small but enough for python
  architectures = ["arm64"] #arm64 

  #env vars needed when adding dynamoDB code
  environment {
    variables = {
      TABLE_NAME = var.table_name #the table name to store the short code and long url

    }
  }

  tags = {
    Project = "serverless-url-shortner"
    Env     = "dev"

  }

}

#recourse will be table arn, 
resource "aws_iam_role_policy" "shortener_dynamoDB" {
  name = "urlshortener-shortener-dynamoDB"
  role = aws_iam_role.shortener_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "DynamoTablePutGet",
      Effect = "Allow",
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ],
      Resource = aws_dynamodb_table.url.arn
    }]
  })
}




#Redirect pieces

#package the redirect lambda into a zip
data "archive_file" "redirect_zip" {
  type        = "zip"                               #create a .zip archive 
  source_dir  = "${path.module}/lambda/redirect"    #source is the folder containing the redirect
  output_path = "${path.module}/build/redirect.zip" #and write it in the build so it gets gitignored
}


#iam roles for redirect
resource "aws_iam_role" "redirect_role" {
  name = "urlshortner-redirect-role" #the visible iam role name
  #allow lambda to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })


}


#now get to logging permissions- cloudWatch logs
resource "aws_iam_role_policy" "redirect_basic" {
  name = "urlshortner-redirect-basic"
  role = aws_iam_role.redirect_role.id #attaching the role to the policy, already created earlier

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "AllowCreateWriteLogs",
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

#now add dynamoDB permissions to read and update table
resource "aws_iam_role_policy" "redirect_dynamodb" {
  name = "urlshortner-redirect-dynamodb"
  role = aws_iam_role.redirect_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "DynamoTableReadUpdate",
      Effect = "Allow",
      Action = [
        "dynamodb:GetItem",   #read the mapping
        "dynamodb:UpdateItem" #update by incremeenting clicks and set last accesssed time
      ],
      Resource = aws_dynamodb_table.url.arn #least priv- this table only
    }]

  })

}


#now create the redirect lambda function
resource "aws_lambda_function" "redirect" {
  function_name = "urlshortner-redirect"         #the function name in aws
  role          = aws_iam_role.redirect_role.arn #execution role

  runtime = "python3.11"             #same runtime as the shortener lambda function
  handler = "handler.lambda_handler" #same handler as the shortener lambda function, the file.fuiinction inside the .zip

  filename         = data.archive_file.redirect_zip.output_path         #the zip file to upload to lambda
  source_code_hash = data.archive_file.redirect_zip.output_base64sha256 #the hash of the zip file to ensure the lambda func is updated when the zip changes

  timeout       = 5 #5 second timeout
  memory_size   = 256
  architectures = ["arm64"] #arm64

  environment {
    variables = {
      TABLE_NAME = var.table_name #the table name to store the short code and long url

    }
  }

  tags = {
    Project = "serverless-url-shortner"
    Env     = "dev"
  }


}



