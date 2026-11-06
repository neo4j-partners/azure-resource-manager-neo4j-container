#!/usr/bin/env bash
# ==============================================================================
# Script: install-neo4j-operator.sh
# Purpose: Installs Neo4j Kubernetes Operator and optional Neo4j instance on AKS
# Used by: Azure Deployment Script (Microsoft.Resources/deploymentScripts) or standalone
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "Starting Neo4j Kubernetes Operator Installation on AKS"
echo "============================================================"

# Required environment variables with defaults
RESOURCE_GROUP="${RESOURCE_GROUP:-}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
OPERATOR_VERSION="${OPERATOR_VERSION:-1.0.0}"
OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-neo4j-operator-system}"
DEPLOY_INSTANCE="${DEPLOY_INSTANCE:-true}"
INSTANCE_NAME="${INSTANCE_NAME:-neo4j-instance}"
NEO4J_EDITION="${NEO4J_EDITION:-enterprise}"
ACCEPT_LICENSE="${ACCEPT_LICENSE:-yes}"
NEO4J_VERSION="${NEO4J_VERSION:-5.26.0}"
TOPOLOGY_MODE="${TOPOLOGY_MODE:-Standalone}"
CLUSTER_CORE_COUNT="${CLUSTER_CORE_COUNT:-3}"
STORAGE_SIZE="${STORAGE_SIZE:-20Gi}"
SERVICE_TYPE="${SERVICE_TYPE:-LoadBalancer}"
NEO4J_PASSWORD="${NEO4J_PASSWORD:-}"
AZ_SCRIPTS_OUTPUT_PATH="${AZ_SCRIPTS_OUTPUT_PATH:-/tmp/deployment-output.json}"

if [[ -z "${RESOURCE_GROUP}" || -z "${CLUSTER_NAME}" ]]; then
  echo "Error: RESOURCE_GROUP and CLUSTER_NAME environment variables must be set." >&2
  exit 1
fi

echo "Configuration:"
echo "  Resource Group:     ${RESOURCE_GROUP}"
echo "  AKS Cluster:        ${CLUSTER_NAME}"
echo "  Operator Version:   ${OPERATOR_VERSION}"
echo "  Operator Namespace: ${OPERATOR_NAMESPACE}"
echo "  Deploy Instance:    ${DEPLOY_INSTANCE}"
echo "  Neo4j Edition:      ${NEO4J_EDITION}"
echo "  Neo4j Version:      ${NEO4J_VERSION}"
echo "  Topology:           ${TOPOLOGY_MODE}"
echo "  Service Type:       ${SERVICE_TYPE}"

# 1. Connect to AKS with retry (handles RBAC propagation delay)
echo "--> Step 1: Connecting to AKS cluster..."
MAX_RETRIES=15
RETRY_DELAY=10
CONNECTED=false

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Attempt $i of $MAX_RETRIES to get AKS credentials..."
  if az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --admin --overwrite-existing 2>/dev/null; then
    if kubectl get nodes --request-timeout='10s' &>/dev/null; then
      CONNECTED=true
      echo "Successfully connected to AKS cluster."
      break
    fi
  fi
  echo "Cluster connection not ready yet. Retrying in ${RETRY_DELAY}s..."
  sleep "${RETRY_DELAY}"
done

if [[ "${CONNECTED}" != "true" ]]; then
  echo "Error: Failed to connect to AKS cluster '${CLUSTER_NAME}' after ${MAX_RETRIES} attempts." >&2
  exit 1
fi

echo "Nodes in cluster:"
kubectl get nodes -o wide

# 2. Install Neo4j CRDs
echo "--> Step 2: Applying Neo4j Custom Resource Definitions (CRDs)..."
CRD_URL="https://github.com/neo4j-partners/neo4j-kubernetes-operator/releases/download/v${OPERATOR_VERSION}/neo4j-crd-${OPERATOR_VERSION}.yaml"
echo "Fetching CRDs from: ${CRD_URL}"

if ! kubectl apply --server-side --force-conflicts -f "${CRD_URL}"; then
  echo "Warning: Direct CRD release URL failed. Attempting fallback CRD apply from helm chart..."
fi

# 3. Install Neo4j Operator via Helm from OCI registry
echo "--> Step 3: Installing Neo4j Operator via Helm (OCI chart)..."
CHART_URL="oci://ghcr.io/neo4j-partners/charts/neo4j-operator"

helm upgrade --install neo4j-operator "${CHART_URL}" \
  --version "${OPERATOR_VERSION}" \
  --namespace "${OPERATOR_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m

echo "Operator deployed successfully. Pods in ${OPERATOR_NAMESPACE}:"
kubectl get pods -n "${OPERATOR_NAMESPACE}"

# 4. Deploy Neo4j Instance (if enabled)
DATABASE_ENDPOINT="N/A"
BOLT_ENDPOINT="N/A"
HTTP_ENDPOINT="N/A"

if [[ "${DEPLOY_INSTANCE}" == "true" ]]; then
  echo "--> Step 4: Deploying Neo4j Custom Resource..."
  APP_NAMESPACE="default"

  # Create secret for authentication if password was supplied, otherwise operator generates one
  if [[ -n "${NEO4J_PASSWORD}" ]]; then
    echo "Creating auth secret for Neo4j..."
    kubectl create secret generic "${INSTANCE_NAME}-auth" \
      --namespace "${APP_NAMESPACE}" \
      --from-literal=NEO4J_AUTH="neo4j/${NEO4J_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi

  # Prepare topology configuration
  TOPOLOGY_CONFIG=""
  if [[ "${TOPOLOGY_MODE}" == "Cluster" && "${NEO4J_EDITION}" == "enterprise" ]]; then
    TOPOLOGY_CONFIG="mode: Cluster
    cluster:
      core:
        servers: ${CLUSTER_CORE_COUNT}"
  else
    TOPOLOGY_CONFIG="mode: Standalone"
  fi

  # Prepare license configuration
  LICENSE_CONFIG=""
  if [[ "${NEO4J_EDITION}" == "enterprise" ]]; then
    LICENSE_CONFIG="license:
    accept: \"${ACCEPT_LICENSE}\""
  fi

  # Prepare manifest
  cat <<EOF > /tmp/neo4j-cr.yaml
apiVersion: neo4j.com/v1
kind: Neo4j
metadata:
  name: ${INSTANCE_NAME}
  namespace: ${APP_NAMESPACE}
spec:
  edition: ${NEO4J_EDITION}
  version: "${NEO4J_VERSION}"
  ${LICENSE_CONFIG}
  topology:
    ${TOPOLOGY_CONFIG}
  storage:
    volumes:
      data:
        mode: Dynamic
        dynamic:
          size: "${STORAGE_SIZE}"
  networking:
    services:
      default:
        type: ${SERVICE_TYPE}
EOF

  echo "Applying Neo4j Manifest:"
  cat /tmp/neo4j-cr.yaml
  kubectl apply -f /tmp/neo4j-cr.yaml

  echo "Waiting for Neo4j instance to start..."
  sleep 15

  # If LoadBalancer, attempt to capture public IP (with timeout)
  if [[ "${SERVICE_TYPE}" == "LoadBalancer" ]]; then
    echo "Resolving LoadBalancer service IP..."
    for ((j=1; j<=30; j++)); do
      SERVICE_IP=$(kubectl get svc -n "${APP_NAMESPACE}" -l "app.kubernetes.io/instance=${INSTANCE_NAME}" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
      if [[ -z "${SERVICE_IP}" ]]; then
        SERVICE_IP=$(kubectl get svc -n "${APP_NAMESPACE}" -l "neo4j.com/instance=${INSTANCE_NAME}" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
      fi
      if [[ -n "${SERVICE_IP}" ]]; then
        echo "Discovered LoadBalancer IP: ${SERVICE_IP}"
        BOLT_ENDPOINT="bolt://${SERVICE_IP}:7687"
        HTTP_ENDPOINT="http://${SERVICE_IP}:7474"
        DATABASE_ENDPOINT="${SERVICE_IP}"
        break
      fi
      echo "Waiting for LoadBalancer IP assignment (attempt $j/30)..."
      sleep 10
    done
  fi

  if [[ "${BOLT_ENDPOINT}" == "N/A" ]]; then
    DATABASE_ENDPOINT="${INSTANCE_NAME}.${APP_NAMESPACE}.svc.cluster.local"
    BOLT_ENDPOINT="bolt://${INSTANCE_NAME}.${APP_NAMESPACE}.svc.cluster.local:7687"
    HTTP_ENDPOINT="http://${INSTANCE_NAME}.${APP_NAMESPACE}.svc.cluster.local:7474"
  fi
fi

# 5. Output results for ARM template consumption
echo "--> Step 5: Generating deployment outputs..."
mkdir -p "$(dirname "${AZ_SCRIPTS_OUTPUT_PATH}")"

cat <<EOF > "${AZ_SCRIPTS_OUTPUT_PATH}"
{
  "status": "Success",
  "operatorNamespace": "${OPERATOR_NAMESPACE}",
  "operatorVersion": "${OPERATOR_VERSION}",
  "databaseEndpoint": "${DATABASE_ENDPOINT}",
  "boltEndpoint": "${BOLT_ENDPOINT}",
  "httpEndpoint": "${HTTP_ENDPOINT}",
  "clusterName": "${CLUSTER_NAME}"
}
EOF

echo "Deployment script output written to ${AZ_SCRIPTS_OUTPUT_PATH}:"
cat "${AZ_SCRIPTS_OUTPUT_PATH}"

echo "============================================================"
echo "Neo4j Kubernetes Operator deployment finished successfully!"
echo "============================================================"

