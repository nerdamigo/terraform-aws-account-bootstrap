output "tags" {
  value = {
    "na:app_id"      = "account_deployment_bootstrapper"
    "na:app_version" = "v1.0.0"
    "na:app_stack_id" = var.app_stack_id
  }
}