locals {
  # make this whatever your organization's "standard" is
  bootstrapping_prefix  = "nerdamigo-bootstrapping"
  bootstrapping_version = "v1"

  aws_account_id = get_aws_account_id()

  bucket_prefix = lower(join("-", flatten([regexall("[a-z0-9]+", local.bootstrapping_prefix), local.aws_account_id])))

  lock_table = lower(join("-", flatten([regexall("[a-z0-9]+", local.bootstrapping_prefix)])))
  state_key  = "bootstrapping/terraform.tfstate"

  # include uuid to prevent caching this value
  identified_app_resources = { for type, resource
    in jsondecode(run_cmd("--terragrunt-quiet", "./bootstrap.sh", "get_resources_by_appid", "account_deployment_bootstrapper", uuid()))
    :
    # group by the second two segments of the arn, lower case
    lower(join(":", slice(split(":", resource.ResourceARN), 1, 3))) => {
      arn  = resource.ResourceARN
      id   = element(reverse(split(":", resource.ResourceARN)), 0)
      tags = { for t in resource.Tags : t.Key => t.Value }
    }...
  }
  # identified_app_resources_echo = run_cmd("echo", "Identified Bootstrapper Resources: '${jsonencode(local.identified_app_resources)}'")

  identified_buckets = [for bucket in lookup(local.identified_app_resources, "aws:s3", []) :
    merge(bucket, {
      has_state = run_cmd("--terragrunt-quiet", "./bootstrap.sh", "get_bucket_has_statekey", bucket.id, local.state_key, uuid())
    })
  ]
  identified_buckets_echo = run_cmd("echo", "Identified Bootstrapper Buckets: '${jsonencode(local.identified_buckets)}'")

  current_backend         = coalesce(one([for b in local.identified_buckets : "remote_${lookup(b.tags, "na:app_version", "v0")}" if b.has_state == "true"]), "local") # find a bucket containing state key, or local
  target_backend          = "remote_${local.bootstrapping_version}"                                                                                                   # this will be the backend to which we migrate state after successful apply
  current_and_target_echo = run_cmd("echo", "Current State Backend '${local.current_backend}', Target State Backend '${local.target_backend}'")

  local_state_backend = <<EOF
terraform {
  backend "local" {
    
  }
}
EOF

  remote_state_backend = <<EOF
terraform {
  backend "s3" {
    bucket = "${local.bucket_prefix}"
    key = "${local.state_key}"
    dynamodb_table = "${local.lock_table}"
  }
}
EOF
}

terraform {
  after_hook "move_generated_files" {
    commands = ["init"]
    execute  = ["sh", "-c", "mv ./__generated_* .."]
  }

  # after an "apply" is run, we can run a "plan" to check that there are no differences, then run the state migrate
  after_hook "migrate_state" {
    commands = ["apply"]
    execute  = ["sh", "-c", "echo 'noop'"]
  }
}

generate "backend" {
  path      = "__generated_backend.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# generated at ${timestamp()}
${length(regexall("remote", local.current_backend)) > 0 ? local.remote_state_backend : local.local_state_backend}
EOF
}

generate "tfvars" {
  path      = "__generated_inputs.auto.tfvars"
  if_exists = "overwrite"
  contents  = <<EOF
# generated at ${timestamp()}
state_bucket_prefix = "${local.bucket_prefix}"
common_tags = {
  "na:app_id" = "account_deployment_bootstrapper"
  "na:app_version" = "${local.bootstrapping_version}"
}
EOF
}