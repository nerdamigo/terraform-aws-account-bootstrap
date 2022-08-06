# generated at ${timestamp()}

locals {
  user_inputs = read_terragrunt_config(find_in_parent_folders("common_user_inputs.hcl")).inputs
  region_details = read_terragrunt_config(find_in_parent_folders("common_region_details.hcl")).inputs
}

inputs = merge(
  local.user_inputs,
  {

})

terraform { 
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
  
  after_hook "describe_command" {
    commands     = [ "terragrunt-read-config" ]
    execute      = [ "echo", "Detection stack running command '$${get_terraform_command()}', with arguments '$${join(" ", get_terraform_cli_args())}'" ]
  }
}

generate "detection" {
    path = "deploy_${region}.tf"
    if_exists = "overwrite"
    contents = <<EOF
# generated at ${timestamp()}
provider "aws" {
  alias = "${id}"
  region = "${region}"
}

module "detection_${id}" {
  source = "./modules/deployed_version_detection"
  app_stack_id = var.app_stack_id
  providers = {
    aws = aws.${id}
  }
}

output "detection_${id}" {
  value = { 
    v1 = module.detection_${id}.v1
  }
}
EOF
}