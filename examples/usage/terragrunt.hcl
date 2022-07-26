terraform {
  # NOTE: when testing, use terragrunt cli option: --terragrunt-source-map 'git::https://github.com/nerdamigo/terraform-aws-account-bootstrap=../..'
  source = "git::https://github.com/nerdamigo/terraform-aws-account-bootstrap//.?ref=v1.0"
  
  before_hook "generate_config" {
    # this list of commands must be comprehensive with respect to those that require/interact w/ the tf state
    # note that if terragrunt detects / decides to run init as a precondition, this hook will run 2x
    commands = [ "init", "plan", "apply", "destroy", "state", "refresh", "force-unlock", "import", "output", "taint" ]
    execute = [ 
      "./bootstrap.sh", 
      "generate_backend",
      get_terraform_command(),
      get_original_terragrunt_dir()
    ]
  }

  # destroy will likely need a before_hook that takes care of "migrating" state local
}

# TODO: determine if/how we might output a "root" or "base" state config hcl - ideally the deployment pipeline(s) should
# be able to just depend on this module - which would supply the necessary config for storing their state. When a 
# change to the state backend is detected, it could be auto-migrated.