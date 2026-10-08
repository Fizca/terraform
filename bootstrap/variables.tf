variable "aws_region" {
  description = "AWS region for the ECR repository. Must match the app layer and the Lambda."
  type        = string
  default     = "us-east-2"
}

variable "app_name" {
  description = "Short name used to prefix AWS resources. Must match the app layer."
  type        = string
  default     = "fennec"
}
