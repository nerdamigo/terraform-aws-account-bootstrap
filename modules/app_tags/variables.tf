variable "app_stack_id" {
  type        = string
  description = "A string that will be used to identify which stack this app's deployment represents"
  validation {
    condition     = lower(regex("[a-z0-9-]+", var.app_stack_id)) == var.app_stack_id
    error_message = "app_stack_id must consist of lowercase characters in the set { a-z, 0-9, - }"
  }
}