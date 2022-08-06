# "global" variables used in other sections; do not edit

locals {
  user_inputs = read_terragrunt_config("common_user_inputs.hcl").inputs

  regions = { for id, region_config in local.user_inputs.regions: 
      id => merge(region_config, {
        id = id
        region = id
      })
  }

  primary_region = one([ for id, region_config in local.regions: region_config if region_config.primary ])

  regions_with_global = merge(local.regions, 
  {
    global = merge(local.primary_region, {
      id = "global"
      primary = false
    })
  })
}

# override / reformat user_inputs
inputs = {
  regions = local.regions
  
  # we use the "primary" region for configuring the "global" config, and for emitting out remote backend config
  primary_region = local.primary_region

  # "global" is regarded as a region - and where things like IAM roles, R53 config would happen
  regions_with_global = local.regions_with_global
}
