#!/bin/bash

set -eu

BUCKET_NAME="$1"
STATE_KEY="$2"
BUCKET_EXISTS=""
KEY_EXISTS=""

set +e
BUCKET_EXISTS=$(bash -c "aws s3api head-bucket --bucket \"${BUCKET_NAME}\" > /dev/null 2>&1 && echo \"bucket_found\"")
if [[ "${BUCKET_EXISTS}" == "bucket_found" ]]; then
    KEY_EXISTS=$(bash -c "aws s3api head-object --bucket \"${BUCKET_NAME}\" --key \"${STATE_KEY}\" > /dev/null 2>&1 && echo \"key_found\"")
fi

set -e

if [[ "${KEY_EXISTS}" == "key_found" ]]; then echo "remote"; else echo "local"; fi