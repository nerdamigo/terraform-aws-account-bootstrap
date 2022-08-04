locals {
  state_prefix = "dns/terraform.tfstate"
}

data "aws_s3_bucket" "v1" {
    for_each = { for item in lookup(local.discovered_resources_grouped, "v1:aws:s3", []) : item.id => item }
    bucket   = each.key
}

data "aws_s3_objects" "v1" {
    for_each = data.aws_s3_bucket.v1

    bucket = each.key
    prefix = local.state_prefix
}

locals {
  v1 = [for key, item in data.aws_s3_objects.v1 :
      {
        bucket = item.bucket
        key    = one(item.keys)
      }
    ]
}

output "v1" {
  value = local.v1
}