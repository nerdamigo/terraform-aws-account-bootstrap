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
  path      = ".generated_dummy_shim.tf"
  if_exists = "overwrite"
  contents  = <<EOF
/*
${jsonencode(dependency.deployment_status.outputs)}
*/
EOF
}

# and generate TF as necessary
generate "deployment" {
  path      = ".generated_state_buckets.tf"
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

//TODO: replication & failover
// challenges:
//  1/ problem with a "duplicate" copy of state; therefore need to limit search to our "primary" region
//  2/ concept of "failover" or otherwise atomic designation of the primary region
//  3/ in the event of a failover, need to disable/ignore mutations/reads to or from the secondary region
// ideas
//  * replication is one thing, but what about backup? versioning would be enabled
//  * something like MFA delete; the "failover" process might need to take over/mutate this policy