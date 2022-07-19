# AWS Account Bootstrapper
The bootstrap process is a required pre-condition for utilizing an AWS account for usage as a target for deployment. Essentially, it takes care of ensuring we have the prerequisites (such as terraform state storage, IAM roles, IAM policies) deployed for usage by the Nerdamigo pipeline and/or local development.

Once bootstrapped, updates/revisions to the bootstrapping version are self-referencing, and your deployment pipeline can simply take a dependency on the [terraform-aws-account-bootstrap module]()

While it may borrow/fork certain modules from other NerdAmigo projects, circular dependencies for development should be avoided. Resources deployed by this module include:

* AWS IAM Policy (nerdamigo_pipeline_access)
* AWS IAM Role (nerdamigo_pipeline_access)
* AWS S3 Bucket (nerdamigo_bootstrap_state_[account_id]_[account_name?])
  * Bucket access logging, encryption, etc (see https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#remote_state)
* AWS DynamoDB Table (nerdamigo_bootstrap_state)

## Getting Started
**Pre-Requisites:**
* AWS Account to be bootstrapped
* Root Access? Admin Access?

## Running
1. Intial Run
    * TF Init runs w/ state configured locally (be sure "disable_init" used for terragrunt - https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#remote_state)
    * Required resources are deployed
    * Backend config re-generated & state migrated (https://www.terraform.io/cli/commands/init#backend-initialization)
0. Running on an already bootstrapped account
    * Option A: The bootstrapper attempts to identify pre-existing resources and bring them into state (terraform plan; for_each check state & import if missing?)
      * This loses the benefit of state locking
    * Option B: The bootstrapper looks for an already-existing state location, and uses it instead of "local" if present; Broken boostrapping requires manual cleanup?
0. Tearing out bootstrapped resources
    * First, create backups for any state file(s) which exist in the bootstrap state bucket
    * `terragrunt destroy` <-- need to consider what the "final" state looks like; might need to precondition by downloading state locally? should a script download the state file ***then*** run the destroy command? perhaps we can do this with a "before" hook on destroy?

## Contributing
You'll need the following installed & available on your command line:
* Terraform
* Terragrunt
* Terratest
* AWS CLI v2

## Module List / Documentation
TODO - https://github.com/terraform-docs/terraform-docs