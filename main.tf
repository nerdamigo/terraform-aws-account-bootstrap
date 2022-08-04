terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

// TODO: consider side-by-side deployment (branches; parallel builds)
//  Workspaces?
locals {

}

//TODO: cloudtrail data events for s3 operations
// https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail
// event selector based on bucket tag...?
// event selector(s) don't support tags, but can auto-create secondary trails to capure data events & manage the
// selector(s) based on tags (good module idea)