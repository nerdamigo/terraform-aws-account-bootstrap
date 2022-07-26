locals {
  # make this whatever your organization's "standard" is
  bootstrapping_prefix = "nerdamigo-bootstrapping"
  bootstrapping_version = "v1"

  aws_account_id = get_aws_account_id()
  bucket_name = lower(join("-", flatten([ regexall("[a-z0-9]+", local.bootstrapping_prefix), local.aws_account_id])))
  lock_table = lower(join("-", flatten([ regexall("[a-z0-9]+", local.bootstrapping_prefix) ])))
  state_key = "bootstrapping/terraform.tfstate"
  
  # include uuid to prevent caching this value
  # TODO: determine how to detect if state is currently "local" (entirely unbootstrapped) vs in a prior "version" of the location(s)
  # could list buckets w/ a tag like "app_name" = "account_deployment_bootstrapper"; with the "app_version" being parsed for the major 
  # component --> "remote_v2"; assuming only one is detected as containing the state_key, that would be our "current" state location
  # and the "target" state location is where we'd like to be after applying this module (so we'd do a state migrate command)
  
  identified_app_resources = { for type, resource 
    in jsondecode(run_cmd("--terragrunt-quiet", "./bootstrap.sh", "get_resources_by_appid", "account_deployment_bootstrapper", uuid()))
     : 
    # group by the second two segments of the arn, lower case
    lower( join(":", slice( split(":", resource.ResourceARN), 1, 3) ) ) => {
      arn = resource.ResourceARN
      id = element(reverse(split(":", resource.ResourceARN)),0)
      tags = { for t in resource.Tags : t.Key => t.Value }
    }...
  }
  # identified_app_resources_echo = run_cmd("echo", "Identified Bootstrapper Resources: '${jsonencode(local.identified_app_resources)}'")

  identified_buckets = [ for bucket in local.identified_app_resources["aws:s3"] :
    merge(bucket, {
      has_state = run_cmd("--terragrunt-quiet", "./bootstrap.sh", "get_bucket_has_statekey", bucket.id, local.state_key, uuid())
    })
  ]
  identified_buckets_echo = run_cmd("echo", "Identified Bootstrapper Buckets: '${jsonencode(local.identified_buckets)}'")

  current_backend = "" # find a bucket containing state key, or local
  target_backend = "remote_${local.bootstrapping_version}" # this will be the backend to which we migrate state after successful apply

  # original version
  # after an "apply" is run, we can run a "plan" to check that there are no differences, then run the state migrate
  identified_state_location = run_cmd("--terragrunt-quiet", "./bootstrap.sh", "get_status", local.bucket_name, local.state_key, uuid())

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
  after_hook "move_generated_files" {
    commands = ["init"]
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
  "na:app_id" = "account_deployment_bootstrapper"
}
EOF
}