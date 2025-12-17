#!/bin/bash
# Workaround for AppIntentsSSUTraining parsing error
# This script creates the expected metadata directory structure

set -e

# Get the build products directory from environment
PRODUCT_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
METADATA_PATH="${PRODUCT_PATH}/Metadata.appintents"

# Create metadata directory if it doesn't exist
mkdir -p "${METADATA_PATH}"

# Create an empty metadata file to satisfy the processor
touch "${METADATA_PATH}/.appintents"

echo "Created AppIntents metadata directory structure"

