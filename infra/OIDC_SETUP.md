# GitHub Actions OIDC Setup Instructions

## AWS IAM Role Trust Policy

The IAM role `github-actions-terraform` needs the following trust policy to allow GitHub Actions to assume it:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/ServerlessURLShortener:*"
        }
      }
    }
  ]
}
```

## Required IAM Permissions

The role should have these permissions:
- `dynamodb:*` (for DynamoDB operations)
- `lambda:*` (for Lambda function management)
- `apigateway:*` (for API Gateway management)
- `iam:*` (for IAM role and policy management)
- `logs:*` (for CloudWatch logs)
- `s3:*` (for Terraform state bucket access)

## Setup Steps

1. **Create OIDC Provider** (if not exists):
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
     --client-id-list sts.amazonaws.com
   ```

2. **Update Trust Policy**: Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username

3. **Create Terraform State Resources**:
   - S3 bucket for state storage
   - DynamoDB table for state locking

4. **Update backend.tfvars** with actual values

## Security Notes

- The OIDC provider uses GitHub's public keys for verification
- Trust policy restricts access to your specific repository
- State files are encrypted at rest
- DynamoDB table prevents concurrent modifications
