variable "channelmonitor-pkg" {
  type    = string
  default = "../../awslive-lambda-channelmonitor/awslive-lambda-channelmonitor.zip"
}

resource "aws_iam_role" "awslive-vodplaylist-role" {
  name = "awslive-vodplaylist-role"
  assume_role_policy = <<EOF
{"Version": "2012-10-17","Statement": [ { "Action": "sts:AssumeRole","Effect": "Allow","Principal": { "Service": ["lambda.amazonaws.com","edgelambda.amazonaws.com"]}}]}

EOF

}

resource "aws_iam_policy" "awslive-vodplaylist-policy" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "medialive:*",
        "lambda:*",
        "iam:PassRole",
        "s3:*",
        "events:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "awslive-vodplaylist-policy-attach" {
  policy_arn = "${aws_iam_policy.awslive-vodplaylist-policy.arn}"
  role = "${aws_iam_role.awslive-vodplaylist-role.name}"
}


resource "aws_lambda_function" "awslive-lambda-channelmonitor" {
  function_name = "awslive-lambda-channelmonitor"
  handler = "awslive-lambda-channelmonitor.lambda_handler"
  role = "${aws_iam_role.awslive-vodplaylist-role.arn}"
  runtime = "ruby2.5"
  filename         = var.channelmonitor-pkg
  source_code_hash = filebase64sha256(var.channelmonitor-pkg)
  environment {
    variables = {
      role_arn = "${aws_iam_role.awslive-vodplaylist-role.arn}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "awslive-lambda-channelmonitor-rule" {
  name = "awslive-lambda-channelmonitor-rule"
  event_pattern = "{\"source\":[\"aws.medialive\"]}"
}

resource "aws_cloudwatch_event_target" "channelmonitor-rule-target" {
  arn = "${aws_lambda_function.awslive-lambda-channelmonitor.arn}"
  rule = "${aws_cloudwatch_event_rule.awslive-lambda-channelmonitor-rule.name}"
}

resource "aws_lambda_permission" "channelmonitor-permission" {
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.awslive-lambda-channelmonitor.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.awslive-lambda-channelmonitor-rule.arn}"
}
