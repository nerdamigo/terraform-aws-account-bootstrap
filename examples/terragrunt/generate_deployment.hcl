locals {
  common_inputs = read_terragrunt_config(find_in_parent_folders("inputs.hcl")).inputs
}

inputs = merge(
  local.common_inputs,
  {

})

# we clone the module, which is largely "noop"
terraform {
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
}

dependency "deployment_status" {
  config_path  = "../detection"
  mock_outputs = {}
}

generate "test_shim" {
  path      = "__generated_dummy_shim.tf"
  if_exists = "overwrite"
  contents  = <<EOF
/*
${jsonencode(dependency.deployment_status.outputs)}
*/
EOF
}

# and generate TF as necessary
generate "deployment" {
  path      = "__generated_state_buckets.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
${join("\n", [for region, region_config in local.common_inputs.regions :
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