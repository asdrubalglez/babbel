variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_language" {
  description = "Language/runtime of the Lambda"
  type        = string
  default     = "nodejs"
  validation {
    condition     = contains(["go","nodejs","typescript","ruby"], var.lambda_language)
    error_message = "lambda_language must be one of: go, nodejs, typescript, ruby"
  }
}