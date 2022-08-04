# NOTE: when developing, use terragrunt cli option 'TERRAGRUNT_SOURCE_MAP': 
#   $ export TERRAGRUNT_SOURCE_MAP="git::https://github.com/nerdamigo/terraform-aws-account-bootstrap=$(realpath ../../)"
# the "source" here is how you would use it for "real"; when deving you need to override and the above command resolves to the root folder of this module

locals {
  common_inputs   = read_terragrunt_config("inputs.hcl").inputs
  create_workdirs = run_cmd("--terragrunt-quiet", "bash", "-c", "mkdir -p __generated/{detection,deployment}")
  deployment_command = compact(flatten([
    "terragrunt",
    [
      get_terraform_cli_args(),
      contains(get_terraform_commands_that_need_locking(), get_terraform_command()) ? "-lock-timeout=20m" : "",
      contains(get_terraform_commands_that_need_input(), get_terraform_command()) ? "-input=false" : ""
    ]
  ]))
}

# need a shim file to keep TG from barking that there is no config here
generate "shim" {
  path      = "__generated_shim.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# generated at ${timestamp()}
EOF
}

generate "detect" {
  path      = "__generated/detection/terragrunt.hcl"
  if_exists = "overwrite"
  contents  = <<EOF
# generated at ${timestamp()}
include "providers" { path = "../../generate_providers.hcl" }
include "detection" { path = "../../generate_detection.hcl" }
EOF
}

generate "deploy" {
  path      = "__generated/deployment/terragrunt.hcl"
  if_exists = "overwrite"
  contents  = <<EOF
# generated at ${timestamp()}
include "providers" { path = "../../generate_providers.hcl" }
include "deployment" { path = "../../generate_deployment.hcl" }
EOF
}

terraform {
  # these only apply to our "shim" - keeping here as a best practice for pipelines
  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }

  extra_arguments "max_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

  # always run detection; config of remote state for depends on detected deployment status
  before_hook "init_detection" {
    commands    = [get_terraform_command()]
    working_dir = "./__generated/detection"
    execute     = ["terragrunt", "init", "-input=false"]
  }
  before_hook "apply_detection" {
    commands    = [get_terraform_command()]
    working_dir = "./__generated/detection"
    execute     = ["terragrunt", "apply", "-input=false", "--auto-approve"]
  }

  # run whatever command was requested against actual boostrap IaC resources
  before_hook "deployment_command_echo" {
    commands    = [get_terraform_command()]
    working_dir = "./__generated/deployment"
    execute     = ["echo", "Executing: '${join(" ", local.deployment_command)}'"]
  }

  before_hook "deployment_init" {
    commands    = [get_terraform_command()]
    working_dir = "./__generated/deployment"
    execute     = ["terragrunt", "init", "-input=false"]
  }
  before_hook "deployment_command" {
    commands    = [get_terraform_command()]
    working_dir = "./__generated/deployment"
    execute     = local.deployment_command
  }

  # cleanup
  after_hook "cleanup_shim" {
    commands     = [get_terraform_command()]
    execute      = ["rm", "-f", "__generated_shim.tf"]
    run_on_error = true
  }
}

/*
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