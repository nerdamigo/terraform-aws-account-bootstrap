data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "app_tags" {
  source = "../app_tags"
  app_stack_id = var.app_stack_id
}

resource "aws_s3_bucket" "state_bucket" {
  bucket = join("-", [var.organization_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.name])

  tags = merge(module.app_tags.tags, var.common_tags)
}

output "bucket" {
  value = aws_s3_bucket.state_bucket.bucket
}

//block public access
resource "aws_s3_bucket_public_access_block" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

//disable ACLs (performance)
resource "aws_s3_bucket_acl" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id
  acl    = "private"
}
resource "aws_s3_bucket_ownership_controls" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

//policy (Authz)
resource "aws_s3_bucket_policy" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid = "allow_all"
    principals {
      type = "AWS"

      # only grants access to this bucket to the owning account
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["*"]
    resources = [aws_s3_bucket.state_bucket.arn, "${aws_s3_bucket.state_bucket.arn}/*"]
  }
}

//logging (skipping for now as it is expected CloudTrail will be used)
// https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudtrail-logging.html

//encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
    }
  }
}

//versioning
resource "aws_s3_bucket_versioning" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

//lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    id = "remove-expired-versions"

    filter {}

    noncurrent_version_expiration {
      newer_noncurrent_versions = 10 # keep up to 10 previous versions
      noncurrent_days = 30 # remove any versions older than 30 days (retaining the count mentioned above)
    }

    status = "Enabled"
  }
}