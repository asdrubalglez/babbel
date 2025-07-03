locals {
  env         = terraform.workspace
  name_prefix = "url-shortener-${local.env}"

  lambda_config = {
    go = {
      dir     = "${path.module}/lambda/go"
      runtime = "go1.x"
      handler = "main"
      zip     = "build/go.zip"
    }
    nodejs = {
      dir     = "${path.module}/lambda/node"
      runtime = "nodejs18.x"
      handler = "index.handler"
      zip     = "build/nodejs.zip"
    }
    typescript = {
      dir     = "${path.module}/lambda/ts"
      runtime = "nodejs18.x"
      handler = "dist/index.handler"
      zip     = "build/typescript.zip"
    }
    ruby = {
      dir     = "${path.module}/lambda/ruby"
      runtime = "ruby2.7"
      handler = "app.handler"
      zip     = "build/ruby.zip"
    }
  }

  selected = local.lambda_config[var.lambda_language]
}