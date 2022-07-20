locals {
  # make this whatever your organization's "standard" is
  bootstrapping_prefix = "nerdamigo-bootstrapping"

  aws_account_id = get_aws_account_id()
  bucket_name = lower(join("-", flatten([ regexall("[a-z0-9]+", local.bootstrapping_prefix), local.aws_account_id])))
  lock_table = lower(join("-", flatten([ regexall("[a-z0-9]+", local.bootstrapping_prefix) ])))
  state_key = "${path_relative_to_include()}/terraform.tfstate"
  
  #include uuid to prevent caching this value
  identified_state_location = run_cmd("--terragrunt-quiet", "./checkBootstrapStateLocation.sh", local.bucket_name, uuid())

  identified_state_location_echo = run_cmd("echo", "State for bootstrapper was identified as '${local.identified_state_location}', using bucket '${local.bucket_name}' and key '${local.state_key}'")
  
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

terraform {
  before_hook "pwd" {
    commands = ["plan"]
    execute = [ "pwd" ]
  }

  before_hook "move_generated_files" {
    commands = ["plan"]
    execute = [ "sh", "-c", "mv ./__generated_* .." ]
  }
}

generate "backend" {
  path      = "__generated_backend.tf"
  if_exists = "overwrite"
  contents = local.identified_state_location == "remote" ? local.remote_state_backend : local.local_state_backend
}

generate "tfvars" {
  path = "__generated_inputs.auto.tfvars"
  if_exists = "overwrite"
  contents = <<EOF
state_bucket_name = "${local.bucket_name}"
common_tags = {
  sample_tag = "sample_value"
}
EOF
}