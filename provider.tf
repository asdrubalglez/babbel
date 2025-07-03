terraform {
  required_version = ">= 1.1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.0" }
  }
  # backend "s3" {
  #   bucket = "my-tf-state-bucket"
  #   key    = "url-shortener/${terraform.workspace}.tfstate"
  #   region = var.aws_region
  # }
}

provider "aws" {
  region = var.aws_region
}