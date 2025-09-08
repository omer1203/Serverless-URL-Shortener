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
      Effect = "Allow",
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


#now that redirect and shortener is set, get started with the HTTP APi

#API gateway HTTP API 
#the HTTP API  will front the lambda functions. 
#Enable permissions CORS so browsers can call without errors
resource "aws_apigatewayv2_api" "http_api" {
  name          = "urlshortner-http-api" #the name in aws
  protocol_type = "HTTP"                 #http api since it is easier and cheaper than rest

  #now add the basic CORS config so can be called by any front end 
  cors_configuration {
    allow_credentials = false                      #not using cookies or auth
    allow_headers     = ["content-type"]           #allow content type headers by users for json
    allow_methods     = ["GET", "POST", "OPTIONS"] #methods that the api will accept
    allow_origins     = ["*"]                      #any origin
    max_age           = 600                        #cache for 10 min
  }

  tags = {
    Project = "serverless-url-shortener"
    Env     = "dev"
  }

}

#now create the integration between the HTTP API and the lambda functions
#with aws proxy and payload format, API gatewya will forward the raw http request as an event to lambda which will be handled in the redirect file 
resource "aws_apigatewayv2_integration" "shorten_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id         #attach to our http api above
  integration_type       = "AWS_PROXY"                              #the integration type, this is the only type that can be used with lambda
  integration_uri        = aws_lambda_function.shortener.invoke_arn #arn to invoke the shortener lambda
  payload_format_version = "2.0"                                    #events uses http api 2.0
  timeout_milliseconds   = 5000                                     #stops after 5s

}

resource "aws_apigatewayv2_integration" "redirect_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.redirect.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 5000

}


#now add the routes- map http method+path to the integration\
resource "aws_apigatewayv2_route" "shorten_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /shorten"                                                       #the method + the path
  target    = "integrations/${aws_apigatewayv2_integration.shorten_integration.id}" #the shortenber integration to use}"

}

resource "aws_apigatewayv2_route" "redirect_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /r/{code}"
  target    = "integrations/${aws_apigatewayv2_integration.redirect_integration.id}" #use the redirect integration id
}



#now add the deployment to the stage
#catch all stage with auto deploy
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default" #special name default stage
  auto_deploy = true       #deploy automatically

  tags = {
    Project = "serverless-url-shortener"
    Env     = "dev"
  }


}



#now allow api gateway to invoke each lambda function--- permissions below
resource "aws_lambda_permission" "allow_api_invoke_shortener" {
  statement_id  = "AllowAPIGatewayInvokeShortener"                     #the statement name/id
  action        = "lambda:InvokeFunction"                              #allow invoking the function
  function_name = aws_lambda_function.shortener.function_name          #which function will be invoked
  principal     = "apigateway.amazonaws.com"                           #who is allowed to invoke the function
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*" #all paths and methods
}
#now do the same for the redirect function
resource "aws_lambda_permission" "allow_api_invoke_redirect" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}





