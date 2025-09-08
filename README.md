
# Serverless URL Shortener (AWS)

A  scalable URL shortener built with API Gateway using HTTP API + AWS Lambda with Python 3.11 + DynamoDB (on-demand), provisioned via Terraform. Includes a tiny HTML+JS frontend.


## Features
* Create short links: POST /shorten returns a 6-char code.
* Redirect: GET /r/{code} issues 301 to the original URL.
* Collision-safe writes via DynamoDB ConditionExpression.
* Click tracking: increments clicks, updates last_accessed.
* CORS enabled for simple web clients.
* Infrastructure as Code with Terraform; least-privilege IAM for each Lambda. 


## Tech Stack

**Infra:** Terraform

**Compute:** AWS Lambda, Python 3.11

**API:** API Gateway- HTTP API v2, proxy integration

**Data:** DynamoDB- Table:URLShortener

**Frontend:** Static HTML + JS (no framework)

## Endpoints

**Request JSON:** {"long_url": "https://somthing.com/some}

**Response JSON:** {"short_code": "ABC123"}
* Validates http:// or https:// and basic URL shape. 
* Rejects invalid or empty URLs

**GET /r/{code}**
**Behavior:**
* Issues 301 Redirect with Location: <long_url>
* On success: 
    * Increments clicks
    * Updates last_accessed (time)

## Prerequisites
* AWS CLI configured for target account & region. 
* Terraform installed. 
* Python 3 for tiny local web server. 

## CI/CD
This repo uses GitHub Actions to plan on Pull Requests and auto-apply on main.
Used AWS OIDC to assume a short-term IAM role to avooid long-lived keys. 
### Workflow under CI/CD
* On Pull Request main: runs terraform init / fmt / validate and plan (does not apply)
* On Push to main: runs the same and auto applies.  

### Deploying
* Create a Pull Request: GitHub Actions posts a Terraform plan. 
* Merge to Main: GitHub Actions runs terraform apply -auto-approve to create: 
    * DynamoDB table URLShortener.
    * Two Lambda functions under shortener and redirect. 
    * API Gateway HTTP API.
    * Required IAM roles & policies for Lambdas. 


## Deployment Infrastructure (From root)  
cd infra  
terraform init  
terraform fmt  
terraform validate  
terraform apply  
terraform output -raw http_api_url (this will get your API base URL)

## Logs and Monitoring
* Lambda logs are available in CloudWatch under: 
    * /aws/lambda/urlshortner-shortener
    * /aws/lambda/urlshortner-redirect

## Implementation
 **Shortener Lambda:**  
* Parses event.body using HTTP API v2, supporting base 64.  
* Validates URL, generates code, writes to DynamoDB with ConditionExpression to avoid collisions. 
**Redirect Lambda:**  
* Reads code from path parameters, uses ConsistentRead to avoid read after write errors. 
* Returns 301 with Location header, updates the clicks and last_accessed. 
**DynamoDB:** 
* Table URLShortener with partition key short_code, which is a string. 
* On-demand billing. 

