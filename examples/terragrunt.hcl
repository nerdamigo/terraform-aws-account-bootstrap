remote_state {
  backend = "s3"
  generate = {
    path      = "__generated_backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "my-terraform-state"

    key = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "my-lock-table"
  }
}

# need to variablize/set calculate using "bootstrap":
#  * config bucket name
#  * config table name