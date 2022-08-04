locals {
  common_inputs = read_terragrunt_config("inputs.hcl").inputs
  create_workdirs = run_cmd("--terragrunt-quiet", "bash", "-c", "mkdir -p __generated/{detection,deployment}")
}

inputs = merge(
  local.common_inputs,
  {

  })

generate "shim" {
  path      = "__generated_shim.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
EOF
}

generate "detect" {
  path      = "__generated/detection/terragrunt.hcl"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
include "providers" { path = "../../generate_providers.hcl" }
include "detection" { path = "../../generate_detection.hcl" }
EOF
}

generate "deploy" {
  path      = "__generated/deployment/terragrunt.hcl"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
include "providers" { path = "../../generate_providers.hcl" }
include "deployment" { path = "../../generate_deployment.hcl" }
EOF
}

terraform {
  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }

  before_hook "apply_detection" {
    commands = [ get_terraform_command() ]
    working_dir = "./__generated/detection"
    execute = [ "terragrunt", "apply" ]
  }
  
  # after_hook "run_deployment" {
  #   commands = [ "terragrunt-read-config" ]
  #   working_dir = "./__generated/deployment"
  #   execute = [ "ls", "-alR", "__generated" ]
  # }
}

/*
# NOTE: when developing, use terragrunt cli option 'TERRAGRUNT_SOURCE_MAP': 
$ export TERRAGRUNT_SOURCE_MAP="git::https://github.com/nerdamigo/terraform-aws-account-bootstrap=$(realpath ../../)"

# the "source" here is how you would use it for "real"; when deving you need to override and the above command resolves to the root folder of this module
terraform {
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"

  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }

  # before_hook "create_detection_workdir" {
  #   commands = [ "init", "plan", "apply", "destroy", "state", "refresh", "force-unlock", "import", "output", "taint" ]
  #   execute = [ "mkdir", "-p", "__generated_detection" ]
  # }

  # before_hook detects, and generates a suitable output file, for the generation of "remote state" blocks as required
  
  # TODO: Determine if can we use "read_terragrunt_config()" to run & execute the "detection" phase, and leverage the outputs (or perhaps as a dependency)

  # before_hook {
  #   # this list of commands must be comprehensive with respect to those that require/interact w/ the tf state
  #   # note that if terragrunt detects / decides to run init as a precondition, this hook will run 2x
  #   commands = [ "init", "plan", "apply", "destroy", "state", "refresh", "force-unlock", "import", "output", "taint" ]
  #   working_dir = "__generated_detection"
  #   execute = [  ] // thinking here we'd execute init & plan in the "detect" subdirectory that we generated
  # }

  # after_hook would take care of migrating state to whatever our deployed end-state is
}

generate "region_providers" {
  path      = "__generated_providers.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()} ${dependency.test.outputs.some_value}
${join("\n", [ for region, region_config in local.common_inputs.regions :
<<PROVIDERS
provider "aws" {
  alias = "${region}"
  region = "${region}"
}
PROVIDERS
])}
EOF
}

generate "state_buckets" {
  path      = "__generated_state_buckets.tf"
  if_exists = "overwrite"
  contents = <<EOF
${join("\n", [ for region, region_config in local.common_inputs.regions :
<<BUCKETS
module "bucket_${region}" {
  source = "./modules/state_bucket"
  organization_prefix = var.organization_prefix
  common_tags = var.common_tags

  providers = {
    aws = aws.${region}
  }
}
BUCKETS
])}
EOF
}

*/