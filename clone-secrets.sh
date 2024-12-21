#!/bin/bash

# Get the source and target stages from command line arguments
source_stage=$1
target_stage=$2

if [ -z "$source_stage" ] || [ -z "$target_stage" ]; then
  echo "Usage: clone-secrets.sh <source_stage> <target_stage>"
  exit 1
fi

# Get secrets from source stage
secrets=$(npx sst secret list --stage=$source_stage)

# Parse and clone each secret
while IFS='=' read -r name value; do
  if [ ! -z "$name" ] && [ ! -z "$value" ] && [[ ! "$name" =~ ^#.* ]]; then
    echo "Cloning $name to stage $target_stage"
    npx sst secret set "$name" "$value" --stage="$target_stage"
  fi
done <<< "$secrets"

echo "Secrets cloned from $source_stage to $target_stage"