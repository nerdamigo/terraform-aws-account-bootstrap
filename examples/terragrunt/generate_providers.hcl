locals {
  common_inputs = read_terragrunt_config(find_in_parent_folders("inputs.hcl")).inputs
}

generate "region_providers" {
  path      = "__generated_providers.tf"
  if_exists = "overwrite"
  contents = <<EOF
# generated at ${timestamp()}
${join("\n", [ for region, region_config in local.common_inputs.regions :
<<PROVIDERS
provider "aws" {
  alias = "${region}"
  region = "${region}"
}
PROVIDERS
])}
EOF
}