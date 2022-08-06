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
  # run detection process to identify any pre-existing deployments of bootstrapping
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

  # before any commands that would depend on state - import those resources if they are not already in state
  # this is to "recover" if we get partway through a deployment before state has been persisted, and fail to migrate state
  #    TODO: for each resource in a deployment's plan, import matching known resources idenfied during detection phase  
  # after_hook "list_known_state" {
  #   commands     = [ "terragrunt-read-config" ]
  #   working_dir  = ".generated"
  #   execute      = [ "bash", "-c", 
  #     "rm -f known-state-addresses.txt && terragrunt run-all state list --terragrunt-include-dir './deployment/*' --terragrunt-non-interactive >> known-state-addresses.txt"
  #   ]
  # }

  # after_hook "import_known_state" {
  #   commands     = [ "terragrunt-read-config" ]
  #   working_dir  = ".generated"
  #   execute      = [ "bash", "-c", 
  #     "xargs -n 1 -I'{}' echo 'Processing State Item: {}' <known-state-addresses.txt"
  #   ]
  # }


  # now we can run whatever command is desired on each of the configured deployment regions + global
  after_hook "run_command" {
    commands     = [ "terragrunt-read-config" ]
    working_dir  = ".generated"
    execute      = flatten([ "terragrunt", "run-all", get_terraform_cli_args(), "--terragrunt-include-dir", "./deployment/*" ])
  }
}