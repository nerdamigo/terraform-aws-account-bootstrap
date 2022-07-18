# terraform-aws-account-bootstrap
Configure an AWS account for usage as part of a Nerdamigo pipeline.

# AWS Account Bootstrapper
This module deploys the resources required for using an AWS Account as a deployment target by NerdAmigo pipelines. While it may borrow/fork certain modules from other NerdAmigo projects, circular dependencies for development should be avoided. Resources deployed by this module include:

* AWS IAM Policy (nerdamigo_pipeline_access)
* AWS IAM Role (nerdamigo_pipeline_access)
* AWS S3 Bucket (nerdamigo_bootstrap_state_[account_id]_[account_name?])
* AWS DynamoDB Table (nerdamigo_bootstrap_state)

## Getting Started
**Pre-Requisites:**
* AWS Account to be bootstrapped
* Root Access? Admin Access?

## Contributing
You'll need the following installed & available on your command line:
* Terraform
* Terragrunt
* Terratest
* AWS CLI v2

## Module List / Documentation
TODO - https://github.com/terraform-docs/terraform-docs