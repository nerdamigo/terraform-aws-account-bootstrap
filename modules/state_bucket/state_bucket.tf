data "aws_caller_identity" "current" { }
data "aws_region" "current" {}

resource "aws_s3_bucket" "state_bucket" {
  bucket = join("-", [ var.organization_prefix, data.aws_caller_identity.current.account_id, data.aws_region.current.name ])

  tags = merge({
  }, var.common_tags)
}

//block public access
resource "aws_s3_bucket_public_access_block" "state_bucket" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
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
            type = "*"
            identifiers = [ "*" ]
        }

        actions = [ "*" ]
        resources = [ aws_s3_bucket.state_bucket.arn, "${aws_s3_bucket.state_bucket.arn}/*" ]
    }
}

//logging (skipping for now as it is expected CloudTrail will be used)
// https://docs.aws.amazon.com/AmazonS3/latest/userguide/cloudtrail-logging.html

//encryption

//versioning

//TODO: replication & failover
// challenges:
//  1/ problem with a "duplicate" copy of state; therefore need to limit search to our "primary" region
//  2/ concept of "failover" or otherwise atomic designation of the primary region
//  3/ in the event of a failover, need to disable/ignore mutations/reads to or from the secondary region
// ideas
//  * replication is one thing, but what about backup? versioning would be enabled
//  * something like MFA delete; the "failover" process might need to take over/mutate this policy

//lifecycle (delete old versions)