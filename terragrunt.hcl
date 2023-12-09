locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  aws_account = local.account_vars.locals.account
  aws_region = local.region_vars.locals.aws_region
}


generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
    required_version = ">= 0.14.5"
      backend "s3" {}
}
EOF
}

remote_state {
  backend = "s3"
  config = {

    bucket = "${local.aws_region}-terraform-state-${local.aws_account}"
    key            = "terragrunt/${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "${local.aws_region}-terraform-locks-${local.aws_account}"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals
)

