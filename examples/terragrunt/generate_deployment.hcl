locals {
  common_inputs = read_terragrunt_config(find_in_parent_folders("inputs.hcl")).inputs
}

inputs = merge(
  local.common_inputs,
  {

  })

generate "deployment" {
  path      = "__generated_deployed_version_detection.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
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

terraform {
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"

  extra_arguments "disable_input" {
    commands  = get_terraform_commands_that_need_input()
    arguments = ["-input=false"]
  }
}

dependency "state_location" {
    config_path = "../detection"
    mock_outputs = { }
}