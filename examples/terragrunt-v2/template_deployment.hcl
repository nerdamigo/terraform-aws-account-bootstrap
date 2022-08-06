# generated at ${timestamp()}

locals {
  user_inputs = read_terragrunt_config(find_in_parent_folders("common_user_inputs.hcl")).inputs
  region_details = read_terragrunt_config(find_in_parent_folders("common_region_details.hcl")).inputs
  detection_output_path = "../../detection/detection-output.json"

  //have to handle the syntax error of }\{ that is present due to how the output from detection is aggregated
  detection_output = fileexists(local.detection_output_path) ? jsondecode(replace(file(local.detection_output_path), "}\n{", ",")) : null
}

inputs = merge(
  local.user_inputs,
  {

})

terraform { 
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
}

generate "detection" {
    path = "detect_${id}.tf"
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