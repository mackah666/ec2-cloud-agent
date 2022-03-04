provider "aws" {
  region = "us-east-2"
}

locals {
  userdata = templatefile("userdata_cw.sh", {
    ssm_cloudwatch_config = aws_ssm_parameter.cw_agent.name
  })
}

resource "aws_instance" "this" {
  ami                  = "ami-0b59bfac6be064b78"
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.this.name
  user_data            = local.userdata
  tags                 = { Name = "EC2-with-cw-agent" }
  # key_name             = key_pair.key_name
}

resource "aws_ssm_parameter" "cw_agent" {
  description = "Cloudwatch agent config to configure custom log"
  name        = "/cloudwatch-agent/config"
  type        = "String"
  value       = file("cw_agent_config.json")
}

resource "random_id" "aws_sqs_name" {
  prefix      = "terraform-sqs-queue-fifo-"
  byte_length = 8
}

resource "random_id" "aws_s3_name" {
  prefix      = "terraform-s3-bucket-"
  byte_length = 8
}


resource "aws_sqs_queue" "terraform_queue" {
  name                        = "${random_id.aws_sqs_name.hex}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

# resource "aws_lambda_event_source_mapping" "lambda52d5d0f" {
#     event_source_arn = "arn:aws:s3:::mackah666-terraform"
#     function_name = "arn:aws:lambda:us-east-2:733041935482:function:hello-mackah666"
#     enabled = true
# }

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

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

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "arn:aws:lambda:us-east-2:733041935482:function:hello-mackah666"
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}


resource "aws_s3_bucket" "bucket" {
  bucket = random_id.aws_s3_name.hex
}

# resource "tls_private_key" "this" {
#   algorithm = "RSA"
# }

# module "key_pair" {
#   source = "terraform-aws-modules/key-pair/aws"

#   key_name   = "deployer-one"
#   public_key = tls_private_key.this.public_key_openssh
# }

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = "arn:aws:lambda:us-east-2:733041935482:function:hello-mackah666"
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
