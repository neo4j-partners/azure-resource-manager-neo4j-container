#!/usr/bin/env bash
# ==============================================================================
# Script: package.sh
# Purpose: Validates and bundles the ARM template and UI definition into a
#          Microsoft Partner Center Marketplace-ready .zip package.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
PACKAGE_NAME="neo4j-kubernetes-operator-marketplace.zip"
PACKAGE_PATH="${DIST_DIR}/${PACKAGE_NAME}"

echo "============================================================"
echo " Packaging Neo4j Operator ARM Template for Azure Marketplace"
echo "============================================================"

# Ensure jq is installed
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required for validation." >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "Error: zip is required to build the package." >&2; exit 1; }

# Step 1: Validate Required Files
echo "==> Step 1: Checking required files..."
REQUIRED_FILES=("mainTemplate.json" "createUiDefinition.json")
for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "${ROOT_DIR}/${file}" ]]; then
    echo "Error: Required file '${file}' is missing from repository root." >&2
    exit 1
  fi
  echo "  [OK] ${file} found."
done

# Step 2: Validate JSON Syntax
echo ""
echo "==> Step 2: Validating JSON syntax..."
for file in "${REQUIRED_FILES[@]}"; do
  if ! jq . "${ROOT_DIR}/${file}" > /dev/null 2>&1; then
    echo "Error: ${file} contains invalid JSON." >&2
    exit 1
  fi
  echo "  [OK] ${file} is valid JSON."
done

# Step 3: Cross-check createUiDefinition outputs with mainTemplate parameters
echo ""
echo "==> Step 3: Cross-checking UI outputs with ARM template parameters..."
TEMPLATE_PARAMS=$(jq -r '.parameters | keys[]' "${ROOT_DIR}/mainTemplate.json" | sort)
UI_OUTPUTS=$(jq -r '.parameters.outputs | keys[]' "${ROOT_DIR}/createUiDefinition.json" | sort)

MISSING_IN_TEMPLATE=0
while read -r output; do
  if [[ -n "${output}" ]]; then
    if ! echo "${TEMPLATE_PARAMS}" | grep -qx "${output}"; then
      echo "  [WARNING] UI output '${output}' is not defined as a parameter in mainTemplate.json."
      MISSING_IN_TEMPLATE=$((MISSING_IN_TEMPLATE + 1))
    else
      echo "  [OK] UI output '${output}' matches template parameter."
    fi
  fi
done <<< "${UI_OUTPUTS}"

if [[ ${MISSING_IN_TEMPLATE} -gt 0 ]]; then
  echo "Warning: There are ${MISSING_IN_TEMPLATE} UI output parameter mismatches."
fi

# Step 4: Create Distribution Zip
echo ""
echo "==> Step 4: Building Marketplace zip package..."
mkdir -p "${DIST_DIR}"
rm -f "${PACKAGE_PATH}"

# We package mainTemplate.json, createUiDefinition.json, and scripts/ into the zip archive
(
  cd "${ROOT_DIR}"
  zip -q -r "${PACKAGE_PATH}" mainTemplate.json createUiDefinition.json scripts/install-neo4j-operator.sh
)

echo "  Package created: ${PACKAGE_PATH}"
echo ""
echo "Package Contents:"
unzip -l "${PACKAGE_PATH}"

# Step 5: Checksum
echo ""
echo "==> Step 5: Package Checksum:"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${PACKAGE_PATH}"
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 "${PACKAGE_PATH}"
fi

echo ""
echo "============================================================"
echo "SUCCESS: Package is ready for Microsoft Partner Center upload!"
echo "Upload file: ${PACKAGE_PATH}"
echo "============================================================"

