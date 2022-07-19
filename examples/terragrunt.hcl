skip = true # don't process this as a terragrunt module

locals {
  aws_account_id = get_aws_account_id()
  repo_basename = run_cmd("--terragrunt-quiet", "basename", get_repo_root())
  bucket_name = lower(join("-", flatten([ regexall("[a-z0-9]+", local.repo_basename), local.aws_account_id])))
  lock_table = lower(join("-", flatten([ regexall("[a-z0-9]+", local.repo_basename) ])))
  state_key = "${path_relative_to_include()}/terraform.tfstate"
  
  #include uuid to prevent caching this value
  identified_state_location = run_cmd("--terragrunt-quiet", "${get_path_to_repo_root()}checkBootstrapStateLocation.sh", local.bucket_name, uuid())

  identified_state_location_echo = run_cmd("echo", "State for bootstrapper was identified as '${local.identified_state_location}'")
  
  local_state_backend = <<EOF
terraform {
  backend "local" {
    
  }
}
EOF

  remote_state_backend = <<EOF
terraform {
  backend "s3" {
    bucket = "${local.bucket_name}"
    key = "${local.state_key}"
    dynamodb_table = "${local.lock_table}"
  }
}
EOF
}

generate "backend" {
  path      = "__generated_backend.tf"
  if_exists = "overwrite"
  contents = local.identified_state_location == "remote" ? local.remote_state_backend : local.local_state_backend
}

# remote_state {
#   backend = "s3"
#   generate = {
#     path      = "__generated_backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
# 
#   config = {
#     bucket = "my-terraform-state"
# 
#     key = "${path_relative_to_include()}/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "my-lock-table"
#   }
# }

# need to variablize/set calculate using "bootstrap":
#  * config bucket name
#  * config table name