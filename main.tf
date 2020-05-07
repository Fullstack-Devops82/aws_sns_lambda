provider "aws" {
  region = "eu-central-1"
}

resource "aws_cloudwatch_event_rule" "console" {
  name        = "${var.prefix}_sentry"
  description = "Capture the CloudTrail events StopLogging and DeleteTrail and send to the lambda function"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "ec2.amazonaws.com"
    ],
    "eventName": [
      "AuthorizeSecurityGroupEgress",
      "AuthorizeSecurityGroupIngress",
      "RevokeSecurityGroupEgress",
      "RevokeSecurityGroupIngress"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.console.name
  target_id = "${var.prefix}_sentry-lambda"
  arn       = aws_lambda_function.lambda.arn
}


resource "aws_iam_role" "lambda" {
  name = "${var.prefix}_sentry-send-alert"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "snsalert1" {
  role      = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "snsalert2" {
  role      = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}


variable "filename" { default = "sentry"}
resource "aws_lambda_function" "lambda" {
  filename           = "${var.filename}.py.zip"
  function_name      = "${var.prefix}-${var.filename}"
  role               = aws_iam_role.lambda.arn
  handler            = "${var.filename}.lambda_handler"
  source_code_hash   = "${filebase64sha256("${var.filename}.py.zip")}"
  runtime            = "python3.7"
  timeout            = 90
  environment {
    variables = {
      sns_topic_arn = aws_sns_topic.vpcTopic.arn
    }
  }
}


resource "aws_lambda_permission" "allow_secret_manager_call_Lambda" {
    function_name = aws_lambda_function.lambda.function_name
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    principal = "events.amazonaws.com"
}

resource "aws_sns_topic" "vpcTopic" {
  name = "vpcTopic"
}
