locals {
  user_inputs = read_terragrunt_config("common_user_inputs.hcl").inputs
  region_details = read_terragrunt_config("common_region_details.hcl").inputs

  generate_target_environment_dirs = run_cmd(
    "--terragrunt-quiet",
      "bash", "-c", 
      "mkdir -p .generated/{detection,deployment}/{${join(",", [ for region, region_config in local.region_details.regions_with_global: region_config.id ])}}"
  )

  # ternary syntax is to ensure that workdirs get generated first; hacky way of enforcing dependency ordering
  generate_detection = length(local.generate_target_environment_dirs) > -1 ? read_terragrunt_config("generate_detection.hcl") : null
  generate_deployments = length(local.generate_target_environment_dirs) > -1 ? read_terragrunt_config("generate_deployments.hcl") : null
}

terraform {
  # phase 1: run detection process to identify any pre-existing deployments of bootstrapping
  after_hook "init_detection" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "terragrunt", "run-all", "init", "-input=false", "--terragrunt-include-dir", "./detection/*" ]
  }
  after_hook "apply_detection" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "terragrunt", "run-all", "apply", "-input=false", "-lock-timeout=0s", "--auto-approve", "--terragrunt-include-dir", "./detection/*", "--terragrunt-non-interactive" ]
  }
  after_hook "output_detection" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated/detection/"
    execute      = [ "bash", "-c", 
      "rm -f detection-output.json && terragrunt run-all output -json >> detection-output.json"
    ]
  }

  # phase 1.1: before any commands that would depend on state - import those resources if they are not already in state
  # this is to "recover" if we get partway through a deployment before state has been persisted, and fail to migrate state

  # phase 2: now we can run whatever command is desired on each of the configured deployment regions + global
  # always init (backend, plugins, etc) - note we ignore "init" in the "run command" subphases
  after_hook "init_deployment" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "terragrunt", "run-all", "init", "-input=false", "--terragrunt-include-dir", "./deployment/*" ]
  }

  after_hook "describe_execution_command" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "echo", "Execution beginning for command '${get_terraform_command()}', with arguments '${join(" ", get_terraform_cli_args())}'" ]
  }

  # phase 2.1: if non-destructive, go ahead
  after_hook "run_requested_deployment_command" {
    commands     = [ !contains([ "init", "destroy" ], get_terraform_command()) ? "terragrunt-read-config" : "noop" ]
    working_dir  = ".generated"
    execute      = flatten([ "terragrunt", "run-all", get_terraform_cli_args(), "--terragrunt-include-dir", "./deployment/*" ])
  }

  # phase 2.1.2: if "apply" - migrate state
  # TODO: regenerate backend for new target destination & migrate state (re-run "apply detection", "output detection", and "init deployment followed by state push?")
  # https://www.terraform.io/cli/commands/state/push

  # phase 2.2: if destructive, first regenerate backend & migrate state
  # TODO: regenerate backend & migrate state (https://www.terraform.io/cli/commands/state/pull)
  # TODO: this should ERROR if the state bucket contains other item(s)
  after_hook "run_requested_destruction_command" {
    commands     = [ contains([ "destroy" ], get_terraform_command()) ? "terragrunt-read-config" : "noop" ]
    working_dir  = ".generated"
    execute      = flatten([ "terragrunt", "run-all", get_terraform_cli_args(), "--terragrunt-include-dir", "./deployment/*" ])
  }
}