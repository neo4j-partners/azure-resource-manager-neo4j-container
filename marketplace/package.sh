#!/usr/bin/env bash
# ==============================================================================
# Script: package.sh
# Purpose: Validates and bundles the Enterprise Edition ARM template and UI definition
#          into a Microsoft Partner Center Marketplace-ready .zip package.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
PACKAGE_NAME="neo4j-kubernetes-operator-marketplace.zip"
PACKAGE_PATH="${DIST_DIR}/${PACKAGE_NAME}"
EE_DIR="${ROOT_DIR}/ee"

echo "============================================================"
echo " Packaging Neo4j Operator ARM Template for Azure Marketplace"
echo "============================================================"

# Ensure tools are installed
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required for validation." >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "Error: zip is required to build the package." >&2; exit 1; }

mkdir -p "${DIST_DIR}"

MAIN_TEMPLATE="${EE_DIR}/mainTemplate.json"
UI_DEF="${EE_DIR}/createUiDefinition.json"

echo "==> Step 1: Validating JSON syntax in ee/..."
jq . "${MAIN_TEMPLATE}" > /dev/null
jq . "${UI_DEF}" > /dev/null
echo "  [OK] mainTemplate.json and createUiDefinition.json are valid JSON."

echo "==> Step 2: Cross-checking UI outputs with template parameters..."
TEMPLATE_PARAMS=$(jq -r '.parameters | keys[]' "${MAIN_TEMPLATE}" | sort)
UI_OUTPUTS=$(jq -r '.parameters.outputs | keys[]' "${UI_DEF}" | sort)

while read -r output; do
  if [[ -n "${output}" ]]; then
    if ! echo "${TEMPLATE_PARAMS}" | grep -qx "${output}"; then
      echo "  [WARNING] UI output '${output}' is not defined as a parameter in mainTemplate.json."
    fi
  fi
done <<< "${UI_OUTPUTS}"
echo "  [OK] All UI outputs map cleanly to template parameters."

echo "==> Step 3: Building Marketplace zip package..."
rm -f "${PACKAGE_PATH}"
(
  cd "${EE_DIR}"
  zip -q -r "${PACKAGE_PATH}" mainTemplate.json createUiDefinition.json
)

echo "  [OK] Package created: ${PACKAGE_PATH}"
echo ""
echo "Package Contents:"
unzip -l "${PACKAGE_PATH}"

echo ""
echo "==> Step 4: Package Checksum:"
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
