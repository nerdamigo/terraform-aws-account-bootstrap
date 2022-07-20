#!/bin/bash

set -eu
OUTPUT_PATH=$1
#terragrunt render-json --terragrunt-json-out "${OUTPUT_PATH}" --terragrunt-config ./state_config.hcl

mkdir -p __generated_stateWorkdir
touch __generated_stateWorkdir/empty.tf

# run TG processing over the state_config to trigger generation of the backend config
# based on whether the target has already been bootstrapped
# comment out the  '2>&1 > /dev/null' if you'd like to see diagnostic output
terragrunt init --terragrunt-working-dir __generated_stateWorkdir --terragrunt-config ./state_config.hcl 2>&1 > /dev/null
rm -rf __generated_stateWorkdir