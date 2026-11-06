#!/usr/bin/env bash
# ==============================================================================
# Script: verify.sh
# Purpose: Offline validation and schema checks for ARM templates and UI definitions.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "============================================================"
echo " Running Local Verification & Schema Checks"
echo "============================================================"

# Check tools
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Error: python3 is required." >&2; exit 1; }

FAILED=0

# Check JSON files
JSON_FILES=(
  "mainTemplate.json"
  "azuredeploy.json"
  "azuredeploy.parameters.json"
  "createUiDefinition.json"
)

for file in "${JSON_FILES[@]}"; do
  filepath="${ROOT_DIR}/${file}"
  if [[ ! -f "${filepath}" ]]; then
    echo "[FAIL] Missing file: ${file}"
    FAILED=$((FAILED + 1))
    continue
  fi

  if jq . "${filepath}" > /dev/null 2>&1; then
    echo "[PASS] JSON syntax valid: ${file}"
  else
    echo "[FAIL] JSON syntax invalid: ${file}"
    FAILED=$((FAILED + 1))
  fi
done

# Python schema & sanity checks
echo ""
echo "Running Template Schema and Structure Analysis..."
python3 - <<'EOF'
import json
import sys

def check_file(filename, validator):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
            return validator(data)
    except Exception as e:
        print(f"[FAIL] Error reading {filename}: {e}")
        return False

def validate_main_template(data):
    errors = []
    if "$schema" not in data:
        errors.append("Missing $schema")
    if "contentVersion" not in data:
        errors.append("Missing contentVersion")
    if "parameters" not in data:
        errors.append("Missing parameters")
    if "resources" not in data:
        errors.append("Missing resources")
    
    resource_types = [r.get("type") for r in data.get("resources", [])]
    expected = [
        "Microsoft.ContainerService/managedClusters",
        "Microsoft.Resources/deploymentScripts",
        "Microsoft.ManagedIdentity/userAssignedIdentities",
        "Microsoft.Authorization/roleAssignments"
    ]
    for exp in expected:
        if exp not in resource_types:
            errors.append(f"Expected resource type {exp} not found in template resources.")

    if errors:
        for err in errors:
            print(f"[FAIL] mainTemplate.json: {err}")
        return False
    print(f"[PASS] mainTemplate.json contains all {len(expected)} expected core resources.")
    return True

def validate_ui_def(data):
    errors = []
    if "$schema" not in data:
        errors.append("Missing $schema")
    if "parameters" not in data:
        errors.append("Missing parameters")
    params = data.get("parameters", {})
    if "steps" not in params or "outputs" not in params:
        errors.append("Missing steps or outputs in parameters")
    
    if errors:
        for err in errors:
            print(f"[FAIL] createUiDefinition.json: {err}")
        return False
    print(f"[PASS] createUiDefinition.json structure confirmed ({len(params.get('steps', []))} steps defined).")
    return True

ok1 = check_file("mainTemplate.json", validate_main_template)
ok2 = check_file("createUiDefinition.json", validate_ui_def)

if not (ok1 and ok2):
    sys.exit(1)
EOF

if [[ $? -eq 0 && ${FAILED} -eq 0 ]]; then
  echo ""
  echo "============================================================"
  echo "All verification checks passed!"
  echo "============================================================"
else
  echo ""
  echo "============================================================"
  echo "Verification encountered errors."
  echo "============================================================"
  exit 1
fi

