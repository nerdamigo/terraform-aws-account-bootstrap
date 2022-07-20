variable "state_bucket_name" {
    type=string
    description="A name for the S3 bucket which will be created to store terraform state"
    validation {
        condition = lower(regex("[a-z0-9-]+", var.state_bucket_name)) == var.state_bucket_name
        error_message = "S3 bucket name must consist of lowercase characters in the set { a-z, 0-9, - }"
    }
}

variable "common_tags" {
    type = map(string)
    description="Map of tags that should be applied to created resources"
}