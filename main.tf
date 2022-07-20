resource "aws_s3_bucket" "state_bucket" {
  bucket = var.state_bucket_name

  tags = merge({
  }, var.common_tags)
}