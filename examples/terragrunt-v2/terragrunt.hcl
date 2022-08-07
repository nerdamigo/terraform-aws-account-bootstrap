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
  after_hook "detection" {
      commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "bash", "-c"
      ,<<CMD
terragrunt run-all init --terragrunt-include-dir './detection/*' --terragrunt-non-interactive --terragrunt-no-auto-init
terragrunt run-all apply -lock-timeout=0s --auto-approve --terragrunt-include-dir './detection/*' --terragrunt-non-interactive --terragrunt-no-auto-init
cd detection && rm -f detection-output.json
terragrunt run-all output -json --terragrunt-no-auto-init >> detection-output.json
CMD
    ]
  }

  # phase 1.1: before any commands that would depend on state - import those resources if they are not already in state
  # this is to "recover" if we get partway through a deployment before state has been persisted, and fail to migrate state

  # phase 2: execution of requested terraform commands in each region
  after_hook "execute" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = [ "bash", "-c"
      ,<<CMD
# ensure init runs before whatever command (so don't run if command IS init)
[ "init" == "${get_terraform_command()}" ] || terragrunt run-all init --terragrunt-include-dir './deployment/*' --terragrunt-non-interactive

# phase 2.1: if non-destructive, go ahead
[ "destroy" == "${get_terraform_command()}" ] || echo "Execution beginning for command '${get_terraform_command()}', with arguments '${join(" ", get_terraform_cli_args())}'"
[ "destroy" == "${get_terraform_command()}" ] || terragrunt run-all ${join(" ", get_terraform_cli_args())} --terragrunt-include-dir './deployment/*' --terragrunt-non-interactive --terragrunt-no-auto-init

# store output values for each stack
pushd deployment
rm -f deployment-output.json
terragrunt run-all output -json --terragrunt-no-auto-init >> deployment-output.json
popd

# phase 2.1.2: if "apply" - migrate state
[ "apply" != "${get_terraform_command()}" ] || MIGRATE_STATE=test_value terragrunt run-all init -migrate-state -force-copy --terragrunt-include-dir './deployment/*' --terragrunt-no-auto-init
CMD
    ]
  }

  # phase 2.2: if destructive, first regenerate backend & migrate state
  # TODO: regenerate backend & migrate state (https://www.terraform.io/cli/commands/state/pull)
  # TODO: this should ERROR if the state bucket contains other item(s)
  after_hook "run_requested_destruction_command" {
    commands     = [ contains([ "destroy" ], get_terraform_command()) ? "terragrunt-read-config" : "noop" ]
    working_dir  = ".generated"
    execute      = flatten([ "terragrunt", "run-all", get_terraform_cli_args(), 
      "--terragrunt-include-dir", "./deployment/*", "--terragrunt-no-auto-init"
    ])
  }
}