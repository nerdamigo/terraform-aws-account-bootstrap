# NOTE: when developing, use terragrunt cli option 'TERRAGRUNT_SOURCE_MAP': 
#   $ export TERRAGRUNT_SOURCE_MAP="git::https://github.com/nerdamigo/terraform-aws-account-bootstrap=$(realpath ../../)"
# the "source" here is how you would use it for "real"; when deving you need to override and the above command resolves to the root folder of this module

locals {
  common_inputs   = read_terragrunt_config("inputs.hcl").inputs

  regions = { for region, region_config in local.common_inputs.regions: 
      region => merge(region_config, {
        region = region
        path = "regions-${region}"
      })
  }

  # we use the "primary" region for configuring the "global" config, and for emitting out remote backend config
  primary_region = one([ 
    for region, region_config in local.common_inputs.regions: 
      merge(region_config, {
        region = region
      })
    if region_config.primary
  ])

  regions_with_global = merge(local.regions, 
  {
    global = merge(local.primary_region, {
      path = "global"
    })
  })
  
  create_workdirs = run_cmd(
    "--terragrunt-quiet",
      "bash", "-c", 
      "mkdir -p .generated/{detection,deployment}/"
  )

  detection_generates = merge(
    { 
      for region, region_config in local.regions_with_global:
      "detection-tf-${region}" => {
        path      = ".generated/detection/${region_config.path}.tf"
        if_exists = "overwrite"
        contents  = <<EOF
# generated at ${timestamp()}
provider "aws" {
  alias = "${region}"
  region = "${region_config.region}"
}

module "detection_${region}" {
  source = "../../../modules/deployed_version_detection"
  providers = {
    aws = aws.${region}
  }
}

output "detection_${region}" {
  value = { 
    v1 = module.detection_${region}.v1
  }
}
EOF
      }
    },
    {
      "detection-tg" = {
        path      = ".generated/detection/terragrunt.hcl"
        if_exists = "overwrite"
        contents  = <<EOF
# generated at ${timestamp()}
terraform { 
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
}
EOF
      }
    })

    # { for region, region_config in local.regions_with_global:
    #   "${region}/detection/tg" => 
    # })

  deployment_generates = merge(
    { for region, region_config in local.regions_with_global:
      "${region}/deployment/tf" => {
        path      = ".generated/deployment/${region_config.path}.tf"
        if_exists = "overwrite"
        contents  = <<EOF
# generated at ${timestamp()}
provider "aws" {
  alias = "${region}"
  region = "${region_config.region}"
}
EOF
      }
    },
    {
      "deployment-tg" = {
        path      = ".generated/deployment/terragrunt.hcl"
        if_exists = "overwrite"
        contents  = <<EOF
# generated at ${timestamp()}
terraform { 
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
}
EOF
      }
    })

  generates = merge(
  # need a shim file to keep TG from barking that there is no config here
    {
      "shim" = {
        path      = ".generated_shim.tf"
          if_exists = "overwrite"
          contents  = <<EOF
# generated at ${timestamp()}
EOF
      }
    },
    local.detection_generates, 
    local.deployment_generates
  )

  #TODO: refactor this into its "base" form (w/o terraform run-all) so it can be used against global, then regions
  deployment_command = compact(flatten([
    get_terraform_cli_args(),
    contains(get_terraform_commands_that_need_locking(), get_terraform_command()) ? "-lock-timeout=20m" : "",
    contains(get_terraform_commands_that_need_input(), get_terraform_command()) ? "-input=false" : ""
  ]))
}

# outputs the files for global + each configured region
generate = local.generates

terraform {  
  # source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"

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
    commands    = [ get_terraform_command() ]
    execute     = [
      "bash", "-c", 
      #"pushd \"$(pwd)/$0\" && ls -al",
      "pushd \"$0\" && terragrunt run-all init -input=false",
      "./.generated/detection/"
    ]
  }
  # before_hook "apply_detection" {
  #   commands    = [ get_terraform_command() ]
  #   execute     = [
  #     "bash", "-c", 
  #     "ls -alR \"$(pwd)/$0\"",
  #     "terragrunt run-all init -input=false --terragrunt-working-dir \"$(pwd)/$0\"",
  #     ".generated/detection/"
  #   ]
  # }


  # # run whatever command was requested against actual boostrap IaC resources
  # before_hook "deployment_command_echo" {
  #   commands    = [ get_terraform_command() ]
  #   execute     = ["echo", "Detection Module(s) updated, now executing: '${join(" ", local.deployment_command)}'"]
  # }
  # before_hook "deployment_init" {
  #   commands    = [ get_terraform_command() ]
  #   execute     = [
  #     "bash", "-c", 
  #     # "ls -alR \"$(pwd)/$0\"",
  #     "terragrunt run-all init -input=false --terragrunt-working-dir \"$(pwd)/$0\"",
  #     ".generated/detection/regions/"
  #   ]
  # }
  
/*
  before_hook "deployment_command" {
    commands    = [get_terraform_command()]
    working_dir = "./.generated/deployment"
    execute     = local.deployment_command
  }
*/

  # cleanup
  after_hook "cleanup_shim" {
    commands     = [get_terraform_command()]
    execute      = ["rm", "-f", ".generated_shim.tf"]
    run_on_error = true
  }
}