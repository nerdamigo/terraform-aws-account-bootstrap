#!/bin/bash

set -eu

USAGE="Usage: $0 command command_argument1 ... command_argumentN"

if [ "$#" == "0" ]; then
	echo "$USAGE"
	exit 1
fi

get_resources_by_appid() {
    local APP_ID=$1    
    local TAG_FILTERS=$(cat <<END
[{"Key":"na:app_id","Values":["${APP_ID}"]}]
END
    )
 
    aws resourcegroupstaggingapi get-resources --tag-filters "${TAG_FILTERS}" --query 'ResourceTagMappingList[]'
}

get_bucket_has_statekey () {
    local BUCKET_NAME=$1
    local STATE_KEY=$2
    local KEY_EXISTS="false"
    set +e
    KEY_EXISTS=$(bash -c "aws s3api head-object --bucket \"${BUCKET_NAME}\" --key \"${STATE_KEY}\" > /dev/null 2>&1 && echo \"true\"")
    set -e
    echo "${KEY_EXISTS}"
}

get_status() {
    set +e
    local BUCKET_NAME=$1
    local STATE_KEY=$2
    local BUCKET_EXISTS=""
    local KEY_EXISTS=""
    BUCKET_EXISTS=$(bash -c "aws s3api head-bucket --bucket \"${BUCKET_NAME}\" > /dev/null 2>&1 && echo \"bucket_found\"")
    if [[ "${BUCKET_EXISTS}" == "bucket_found" ]]; then
        KEY_EXISTS=$(bash -c "aws s3api head-object --bucket \"${BUCKET_NAME}\" --key \"${STATE_KEY}\" > /dev/null 2>&1 && echo \"key_found\"")
    fi
    set -e

    if [[ "${KEY_EXISTS}" == "key_found" ]]; then echo "remote"; else echo "local"; fi
}

generate_backend() {
    TF_COMMAND=$1

    echo "Generating backend configuration for execution of command '${TF_COMMAND}'"
    mkdir -p .generated_stateWorkdir
    touch .generated_stateWorkdir/empty.tf

    # run TG processing over the state_config to trigger generation of the backend config
    # based on whether the target has already been bootstrapped
    # comment out the  '2>&1 > /dev/null' if you'd like to see diagnostic output
    terragrunt init --terragrunt-working-dir .generated_stateWorkdir --terragrunt-config ./bootstrap.hcl #2>&1 > /dev/null
    rm -rf .generated_stateWorkdir
}

COMMAND=$1
shift

$COMMAND $@