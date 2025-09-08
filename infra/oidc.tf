#Github OIDC provider. 
#Github Actions requestion using short term credentials

resource "aws_iam_openid_connect_provider" "github" {
    url = "https://token.actions.githubusercontent.com" #githubs oidc issuer

    client_id_list = ["sts.amazonaws.com"] #client is aws sts
    thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] #oidc endpoint on github actions page
  
}

#now for the iam role that will be assumed by github actions 
resource "aws_iam_role" "github_actions" {
    name = "github-actions-terraform"

    assume_role_policy = jsonencode({ 
        Version = "2012-10-17",
        Statement = [{
            Effect = "Allow",
            Principal = { Federated = aws_iam_openid_connect_provider.github.arn }, #the identity provider that was crated above
            Action = "sts:AssumeRoleWithWebIdentity", #this is the only action allowed for oid
            Condition = {
                StringEquals = {
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                },
                StringLike = { 
                    "token.actions.githubusercontent.com:sub" = "repo:omer1203/Serverless-URL-Shortener:ref:refs/heads/main"
                }
            }
        }]
    })
}


#permissions for the role, give administrator access
resource "aws_iam_role_policy_attachment" "github_admin" {
    role = aws_iam_role.github_actions.name
    policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  
}

