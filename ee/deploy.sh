#!/usr/bin/env bash
# ==============================================================================
# Script: ee/deploy.sh
# Purpose: Deploys Neo4j Enterprise Edition on AKS using the ARM template.
# Usage: ./deploy.sh [OPTIONS] [RESOURCE_GROUP_NAME]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/mainTemplate.json"

# Defaults
RESOURCE_GROUP="${1:-}"
LOCATION="eastus"
CLUSTER_NAME=""
OPERATOR_VERSION="1.0.0"
OPERATOR_NAMESPACE="neo4j-operator-system"
NEO4J_EDITION="enterprise"
ACCEPT_LICENSE="true"
TOPOLOGY_MODE="Cluster"
CLUSTER_CORE_COUNT=3
STORAGE_SIZE="50Gi"
NEO4J_PASSWORD=""
SERVICE_TYPE="LoadBalancer"
AUTO_CONFIRM=false

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [RESOURCE_GROUP_NAME]

Deploy Neo4j Enterprise Edition on Azure Kubernetes Service (AKS).

Arguments:
  RESOURCE_GROUP_NAME        Name of the target Azure Resource Group.

Options:
  -g, --resource-group NAME  Name of the Azure Resource Group.
  -l, --location REGION      Azure region (default: ${LOCATION}).
  -c, --cluster-name NAME    AKS Cluster name (default: neo4j-ee-<random>).
  -t, --topology TOPOLOGY    Topology mode: 'Cluster' or 'Standalone' (default: ${TOPOLOGY_MODE}).
  -n, --cluster-size NUM     Number of core servers in the cluster (default: ${CLUSTER_CORE_COUNT}).
  -p, --password PASSWORD    Initial password for neo4j user.
  -v, --operator-version VER Operator version (default: ${OPERATOR_VERSION}).
  -s, --storage-size SIZE    Data volume size (default: ${STORAGE_SIZE}).
  -y, --yes                  Skip interactive confirmations.
  -h, --help                 Show this help message.

Examples:
  ./deploy.sh my-neo4j-ee-rg
  ./deploy.sh -g my-neo4j-ee-rg -l westeurope -t Cluster -n 3 -p "MySecretPassw0rd!"
EOF
  exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -c|--cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    -t|--topology)
      TOPOLOGY_MODE="$2"
      shift 2
      ;;
    -n|--cluster-size)
      CLUSTER_CORE_COUNT="$2"
      shift 2
      ;;
    -p|--password)
      NEO4J_PASSWORD="$2"
      shift 2
      ;;
    -v|--operator-version)
      OPERATOR_VERSION="$2"
      shift 2
      ;;
    -s|--storage-size)
      STORAGE_SIZE="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_CONFIRM=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "${RESOURCE_GROUP}" ]]; then
        RESOURCE_GROUP="$1"
        shift
      else
        echo "Unknown option: $1" >&2
        usage
      fi
      ;;
  esac
done

echo "============================================================"
echo " Neo4j Enterprise Edition on AKS - Deployment Manager"
echo "============================================================"

# Check prerequisites
command -v az >/dev/null 2>&1 || { echo "Error: Azure CLI ('az') is required but not installed." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' is required but not installed." >&2; exit 1; }

# Verify Azure login
echo "Checking Azure CLI authentication..."
CURRENT_ACCOUNT=$(az account show --output json 2>/dev/null || true)
if [[ -z "${CURRENT_ACCOUNT}" ]]; then
  echo "Error: You are not logged into Azure. Please run 'az login' first." >&2
  exit 1
fi

SUBSCRIPTION_NAME=$(echo "${CURRENT_ACCOUNT}" | jq -r '.name')
SUBSCRIPTION_ID=$(echo "${CURRENT_ACCOUNT}" | jq -r '.id')
echo "Target Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

# Prompt for Resource Group if missing
if [[ -z "${RESOURCE_GROUP}" ]]; then
  read -rp "Enter Azure Resource Group name: " RESOURCE_GROUP
  if [[ -z "${RESOURCE_GROUP}" ]]; then
    echo "Error: Resource Group name cannot be empty." >&2
    exit 1
  fi
fi

# Generate default cluster name if missing
if [[ -z "${CLUSTER_NAME}" ]]; then
  RANDOM_SUFFIX=$(head /dev/urandom | LC_ALL=C tr -dc 'a-z0-9' | head -c 5 || echo "aks")
  CLUSTER_NAME="neo4j-ee-${RANDOM_SUFFIX}"
fi

echo ""
echo "Deployment Plan:"
echo "  Subscription:        ${SUBSCRIPTION_NAME}"
echo "  Resource Group:      ${RESOURCE_GROUP}"
echo "  Location:            ${LOCATION}"
echo "  AKS Cluster Name:    ${CLUSTER_NAME}"
echo "  Edition:             Enterprise Edition"
echo "  Topology Mode:       ${TOPOLOGY_MODE}"
echo "  Core Members:        ${CLUSTER_CORE_COUNT}"
echo "  Operator Version:    ${OPERATOR_VERSION}"
echo "  Storage Size:        ${STORAGE_SIZE}"
echo "  Service Type:        ${SERVICE_TYPE}"
echo ""

if [[ "${AUTO_CONFIRM}" != "true" ]]; then
  read -rp "Proceed with Enterprise deployment? [y/N]: " CONFIRM
  if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled by user."
    exit 0
  fi
fi

# Step 1: Ensure Resource Group exists
echo ""
echo "==> Step 1: Ensuring Resource Group '${RESOURCE_GROUP}' exists in '${LOCATION}'..."
if ! az group show --name "${RESOURCE_GROUP}" &>/dev/null; then
  echo "Creating resource group '${RESOURCE_GROUP}'..."
  az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output table
else
  echo "Resource group '${RESOURCE_GROUP}' already exists."
fi

# Step 2: Validate ARM Template
echo ""
echo "==> Step 2: Validating ARM Template..."
VALIDATION_OUTPUT=$(az deployment group validate \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters \
    clusterName="${CLUSTER_NAME}" \
    location="${LOCATION}" \
    operatorVersion="${OPERATOR_VERSION}" \
    operatorNamespace="${OPERATOR_NAMESPACE}" \
    neo4jEdition="enterprise" \
    acceptLicense="true" \
    topologyMode="${TOPOLOGY_MODE}" \
    clusterCoreCount="${CLUSTER_CORE_COUNT}" \
    storageSize="${STORAGE_SIZE}" \
    serviceType="${SERVICE_TYPE}" \
    neo4jPassword="${NEO4J_PASSWORD}" \
  --output json 2>&1)

if echo "${VALIDATION_OUTPUT}" | jq -e '.error' &>/dev/null; then
  echo "Template validation failed:"
  echo "${VALIDATION_OUTPUT}" | jq .error
  exit 1
fi
echo "Template validation passed successfully."

# Step 3: Run Deployment
DEPLOYMENT_NAME="neo4j-ee-$(date +%s)"
echo ""
echo "==> Step 3: Initiating ARM Deployment '${DEPLOYMENT_NAME}'..."
echo "This provisions AKS and boots the Neo4j Enterprise cluster. This typically takes 6-10 minutes."

DEPLOY_RESULT=$(az deployment group create \
  --name "${DEPLOYMENT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameters \
    clusterName="${CLUSTER_NAME}" \
    location="${LOCATION}" \
    operatorVersion="${OPERATOR_VERSION}" \
    operatorNamespace="${OPERATOR_NAMESPACE}" \
    neo4jEdition="enterprise" \
    acceptLicense="true" \
    topologyMode="${TOPOLOGY_MODE}" \
    clusterCoreCount="${CLUSTER_CORE_COUNT}" \
    storageSize="${STORAGE_SIZE}" \
    serviceType="${SERVICE_TYPE}" \
    neo4jPassword="${NEO4J_PASSWORD}" \
  --output json)

echo ""
echo "============================================================"
echo " Neo4j Enterprise Edition Deployment Complete!"
echo "============================================================"

HTTP_ENDPOINT=$(echo "${DEPLOY_RESULT}" | jq -r '.properties.outputs.httpEndpoint.value // empty')
BOLT_ENDPOINT=$(echo "${DEPLOY_RESULT}" | jq -r '.properties.outputs.boltEndpoint.value // empty')
STATUS=$(echo "${DEPLOY_RESULT}" | jq -r '.properties.outputs.status.value // "Unknown"')
CONNECT_CMD=$(echo "${DEPLOY_RESULT}" | jq -r '.properties.outputs.aksConnectCommand.value // empty')

echo "Operator Status:      ${STATUS}"
echo "Neo4j HTTP (Browser): ${HTTP_ENDPOINT}"
echo "Neo4j Bolt:           ${BOLT_ENDPOINT}"
echo ""
echo "Connect to AKS with kubectl:"
echo "  ${CONNECT_CMD}"
echo ""
echo "List pods in the operator namespace:"
echo "  kubectl get pods -n ${OPERATOR_NAMESPACE}"
echo ""
echo "View Enterprise Cluster Status:"
echo "  kubectl get neo4j"
echo "============================================================"

