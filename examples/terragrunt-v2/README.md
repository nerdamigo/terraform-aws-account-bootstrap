# AWS Account Bootstrapper - Terragrunt Usage Example

As this terraform module only provides the capability to detect the status of deployment and deploy bootstrapping resources, but does
not orchestrate those activities, it is left to the user to leverage a suitable toolchain for that purpose. In this example we use
[Terragrunt](https://terragrunt.gruntwork.io/)'s ability to generate and execute terraform to aid us.

This example effectively operates in multiple phases:

## Phase 1 - Detection
For each desired target region + "global" - we run this modules' "detection" capability, outputting what it discovers for usage in phase 2.

### Phase 1.1 - TODO - State Import
Before running any commands that depend on state, we import detected resources matching this stack's `app_id`, `app_stack_id`, and 
`app_version` according to the (TBD: plan? based on another tag on each indicating the "correct" address for a resource?)

## Phase 2 - Execution
Again in each region + "global" we use the detected presence of pre-existing deployments to determine where our terraform state is stored,
rendering an appropriate backend configuration for terraform to use. For all commands, we run "init" first.

### Phase 2.1 - Deployment
For non-destructive commands, we run the requested terraform command against this modules' resources.

### Phase 2.1.2 - State Migration
If we executed an "apply" command successfully, we regenerate the backend configuration, and execute a terraform state migration to ensure
it is moved from wherever it was previously to its new desired home (local -> remote_v1, or remote_v1 -> remote_v2, etc).

### Phase 2.2 - Destruction
If we are requested to execute a "destroy", we must first migrate state if it is stored remotely. After migrating, we can execute the 
"destroy" command.

# Appendix / Notes
## Phase 1.1 thoughts
```
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
```