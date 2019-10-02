# About:
# this is a stubbed out terraform configuration for a lambda
# function that is invoked on a schedule. it has read and write
# access to an s3 bucket for persisting state.
#
# choose names in the places called "edit me"

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    #edit me - create a bucket for persisting terraform state and
    # write the name here. do this before your first terraform init.
    bucket = "my-terraform-state"

    key     = "terraform.tfstate"
    region  = "us-east-1"
    encrypt = 1
  }
}

variable "terraform_kms_key" {
  description = "Identifier of KMS key for terraform state locking table"
  type        = "string"

  #edit me
  default = ""
}

variable "lambda_policy" {
  description = "Policy name for IAM"
  type        = "string"

  # edit me
  default = "cronPolicy"
}

variable "cron_state_bucket" {
  description = "Name of state bucket for cron jobs"
  type        = "string"

  # edit me
  default = "cron-state-bucket"
}

variable "cron_function_name" {
  description = "Name of cron job function name"
  type        = "string"

  # edit me
  default = "cronJob"
}

variable "cron_handler" {
  description = "Name of handler in your code"
  type        = "string"
  default     = "handler"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "${var.lambda_policy}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "s3_access" {
  name        = "s3_access"
  path        = "/"
  description = "IAM policy for access to s3 bucket"

  # edit "Resource" with same value as line 59
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::cron-state-bucket/*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.s3_access.arn}"
}

resource "aws_s3_bucket" "cron-job" {
  bucket = "${var.cron_state_bucket}"
}

resource "aws_cloudwatch_log_group" "cron_job_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.cron_job.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_function" "cron_job" {
  # edit me with desired filename
  # and read all the comments in this resource
  filename = "cron.zip"

  function_name = "${var.cron_function_name}"
  role          = "${aws_iam_role.iam_for_lambda.arn}"
  handler       = "${var.cron_handler}"

  # repeat from filename above
  source_code_hash = "${base64sha256(file("cron.zip"))}"

  # use your desired runtime here - this is for rust
  # see https://docs.aws.amazon.com/lambda/latest/dg/API_CreateFunction.html#SSS-CreateFunction-request-Runtime
  runtime = "provided"

  # edit me - environment variables go here
  environment = {
    variables = {}
  }
}

resource "aws_cloudwatch_event_rule" "lambda_rate" {
  name = "lambda_rate"

  depends_on = [
    "aws_lambda_function.cron_job",
  ]

  # edit me - this runs every day at 1am
  # see https://docs.aws.amazon.com/lambda/latest/dg/tutorial-scheduled-events-schedule-expressions.html
  # for writing your own schedule
  schedule_expression = "cron(0 1 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cron_job_lambda_events" {
  target_id = "ffm_down_bot_lambda"
  rule      = "${aws_cloudwatch_event_rule.lambda_rate.name}"
  arn       = "${aws_lambda_function.cron_job.arn}"
}

resource "aws_lambda_permission" "lambda_rate" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cron_job.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lambda_rate.arn}"
}
