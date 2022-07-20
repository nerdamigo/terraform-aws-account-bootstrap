terraform {
  # use the terraform module at the root of this registry; when bootstrapping a "real" environment, you'd use one of the other
  # supported terraform module source uri formats
  #source = "../..//."
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
  
  before_hook "generate_backend_config" {
    commands = [ "init" ]
    execute = [ 
      "./bootstrapState.sh", 
      "${get_original_terragrunt_dir()}"
    ]
  }
}