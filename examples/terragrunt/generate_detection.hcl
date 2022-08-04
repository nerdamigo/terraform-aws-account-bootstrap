locals {
  common_inputs = read_terragrunt_config(find_in_parent_folders("inputs.hcl")).inputs
}

inputs = merge(
  local.common_inputs,
  {

})

generate "deployed_version_detection" {
  path      = "__generated_deployed_version_detection.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
${join("\n", [for region, region_config in local.common_inputs.regions :
  <<DETECTION
module "detection_${region}" {
  source = "./modules/deployed_version_detection"
  providers = {
    aws = aws.${region}
  }
}

output "detection_${region}" {
  value = { 
    v1 = module.detection_${region}.v1
  }
}
DETECTION
])}
EOF
}

terraform {
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
}