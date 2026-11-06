# Neo4j Enterprise Edition on Azure Kubernetes Service (AKS)

This directory contains the Azure Resource Manager (ARM) template, Azure Marketplace UI definition, and deployment scripts configured specifically for **Neo4j Enterprise Edition (EE)** on **Azure Kubernetes Service (AKS)** using the [Neo4j Kubernetes Operator](https://github.com/neo4j-partners/neo4j-kubernetes-operator).

---

## Features

- **Autonomous Raft Clustering**: Deploys a high-availability multi-core cluster (default: 3 core members) managed by the Neo4j Operator.
- **Enterprise Storage**: Dynamic provisioning of persistent volumes using Azure Managed Disks (default: 50Gi Premium SSD / Standard SSD).
- **Public / Internal Connectivity**: Exposes Neo4j Browser (HTTP 7474) and Bolt protocol (7687) via an Azure Load Balancer.
- **Automated Lifecycle Operations**: Supports rolling upgrades, automated failure recovery, backups, and horizontal scaling.

---

## Deploy Using `deploy.sh`

Deploy directly to your Azure subscription via the Azure CLI:

```bash
cd ee
./deploy.sh <RESOURCE_GROUP_NAME>
```

### Advanced Deployment Options

```bash
./deploy.sh \
  --resource-group neo4j-ee-rg \
  --location eastus \
  --cluster-name neo4j-ee-cluster \
  --topology Cluster \
  --cluster-size 3 \
  --storage-size 100Gi \
  --password "YourStrongPassword123!" \
  --yes
```

---

## Template Files

| File | Description |
| :--- | :--- |
| [`mainTemplate.json`](mainTemplate.json) | The core ARM template defining the AKS cluster, Managed Identity, and Deployment Script. |
| [`azuredeploy.json`](azuredeploy.json) | Standard ARM entry point mirroring `mainTemplate.json`. |
| [`createUiDefinition.json`](createUiDefinition.json) | Azure Portal UI wizard definition tailored for Enterprise Edition Marketplace offers. |
| [`azuredeploy.parameters.json`](azuredeploy.parameters.json) | Default parameter values for local and automated testing. |
| [`deploy.sh`](deploy.sh) | Automated bash deployment script for Azure CLI. |

---

## Connecting to the Cluster

Once deployment completes, connect to your AKS cluster:

```bash
az aks get-credentials --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME>
```

Verify the operator and enterprise cluster pods:

```bash
# Check operator
kubectl get pods -n neo4j-operator-system

# Check Enterprise cluster core members
kubectl get pods -l app.kubernetes.io/name=neo4j

# View custom resource status
kubectl get neo4j
kubectl describe neo4j neo4j-enterprise
```

---

## Tearing Down the Deployment

To delete all provisioned cloud resources:

```bash
az group delete --yes --name <RESOURCE_GROUP_NAME>
```

