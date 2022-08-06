# generated at ${timestamp()}

locals {
  user_inputs = read_terragrunt_config(find_in_parent_folders("common_user_inputs.hcl")).inputs
  region_details = read_terragrunt_config(find_in_parent_folders("common_region_details.hcl")).inputs
  detection_output_path = "../../detection/detection-output.json"

  //have to handle the syntax error of }\{ that is present due to how the output from detection is aggregated
  detection_output = fileexists(local.detection_output_path) ? jsondecode(replace(file(local.detection_output_path), "}\n{", ",")) : null

  //determine if "official" state for this deployment is:
  // * local (no deployments detected)
  // * remote_v[other_app_version] (version other than current detected as already deployed)
  // * remote_v[app_version] (current version detected as already deployed)
  // selection of "official" state file is based on the file w/ the highest "serial"
}

inputs = merge(
  local.user_inputs,
  {

})

terraform { 
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"

  after_hook "describe_execution_command" {
    commands     = [ "terragrunt-read-config" ]
    execute      = [ "echo", "Deployment stack running command '$${get_terraform_command()}', with arguments '$${join(" ", get_terraform_cli_args())}'" ]
  }
}

generate "backend" {
  path = "backend.tf"
  if_exists = "overwrite"
  contents = <<LOCAL
# generated at ${timestamp()}
# for command '$${get_terraform_command()}', with arguments '$${join(" ", get_terraform_cli_args())}'
# MIGRATE_STATE='$${get_env("MIGRATE_STATE", "")}'
/*
$${jsonencode(local.detection_output)}
*/
terraform {
  # keep local state outside our generated directory for safekeeping in case we purge & regenerate
  backend "local" {
    path = "${terragrunt_dir}/deployment-${id}.tfstate"
  }
}
LOCAL
}

generate "deployment" {
    path = "deployment_${id}.tf"
    if_exists = "overwrite"
    contents = <<EOF
# generated at ${timestamp()}

# region-appropriate provider
provider "aws" {
  alias = "${id}"
  region = "${region}"
}

# IAM roles/policies (replication, user deployment)

# state bucket
%{if id != "global" }
module "state_bucket_${region}" {
  source = "./modules/state_bucket"
  
  organization_prefix = var.organization_prefix
  app_stack_id = var.app_stack_id
  common_tags = var.common_tags

  providers = {
    aws = aws.${region}
  }
}

%{endif}

EOF
}