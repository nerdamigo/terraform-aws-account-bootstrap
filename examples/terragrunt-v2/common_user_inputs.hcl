# // configurable for your organization
inputs = {
  organization_prefix = "nabs"
  app_stack_id = "example"

  regions = {
    "us-west-2" = { primary = true }
    "us-east-1" = { primary = false }
  }

  common_tags = {
  }
}