#create soime output blocks for useful details
output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.url.name


}

output "table_arn" {
  description = "DynamoDB table arn"
  value       = aws_dynamodb_table.url.arn

}