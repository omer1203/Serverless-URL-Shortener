#create soime output blocks for useful details
output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.url.name


}

output "table_arn" {
  description = "DynamoDB table arn"
  value       = aws_dynamodb_table.url.arn

}

#output the url of the api gateway
output "http_api_url" {
  description = "Base URL for the HTTP API"
  value       = aws_apigatewayv2_api.http_api.api_endpoint #the endpoint of the api call 

}