#!/bin/bash

set -eu

BUCKET_NAME="$1"

set +e
BUCKET_EXISTS=$(bash -c "aws s3api head-bucket --bucket \"${BUCKET_NAME}\" > /dev/null 2>&1 && echo \"remote\"")
set -e

echo ${BUCKET_EXISTS:-local}