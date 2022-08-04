terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

module "app_tags" {
  source = "../app_tags"
}

locals {
  app_id = module.app_tags.tags["na:app_id"]
}

# uses data types to "discover" deployed versions of boostrapper resources
data "aws_resourcegroupstaggingapi_resources" "target" {
  tag_filter {
    key    = "na:app_id"
    values = [local.app_id]
  }

  tag_filter {
    key = "na:app_version"
  }
}

locals {
  discovered_resources_grouped = { for resource in data.aws_resourcegroupstaggingapi_resources.target.resource_tag_mapping_list :
    # group by the major version & second two segments of the arn, lower case
    lower(join(":", flatten([
      slice(split(".", resource.tags["na:app_version"]), 0, 1),
      slice(split(":", resource.resource_arn), 1, 3)
    ]))) =>

    merge(resource, {
      id      = element(reverse(split(":", resource.resource_arn)), 0)
      version = resource.tags["na:app_version"]
    })...
  }
}

output "discovered_resources_grouped" {
  value = local.discovered_resources_grouped
}