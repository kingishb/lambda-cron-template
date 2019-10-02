## Lambda Cron Template
This is a template terraform configuration for invoking cron
jobs as lambda functions. It has access to S3 to persist state between invocations. Go through `lambda-cron.tf` and everywhere it says "edit me" add names for your own resources. In the `aws_lambda_function` resources use [this reference](https://www.terraform.io/docs/providers/aws/r/lambda_function.html) for the appropriate runtime and details. 
