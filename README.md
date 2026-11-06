# azure-resource-manager-neo4j-container

This repository contains Azure Resource Manager (ARM) templates used to deploy the official [Neo4j Kubernetes Operator](https://github.com/neo4j-partners/neo4j-kubernetes-operator) and Neo4j on Microsoft Azure. These templates power the Neo4j offerings in the Azure Marketplace.

---

## Deploying from the Command Line

You can run these templates from the preconfigured Azure Cloud Shell in the Azure Portal, or locally using the Azure CLI.

### 1. Clone the repository

```bash
git clone https://github.com/neo4j-partners/azure-resource-manager-neo4j-container.git
cd azure-resource-manager-neo4j-container
```

### 2. Navigate to Enterprise Edition

```bash
cd ee
```

### 3. Run the deployment script

Review `deploy.sh` and execute it by passing a target Azure Resource Group name:

```bash
./deploy.sh <RESOURCE_GROUP_NAME>
```

Optional flags can be passed to customize the deployment:

```bash
./deploy.sh -g my-neo4j-rg -l eastus -t Cluster -n 3 -p "YourPassword123!" --yes
```

Upon completion, the deployment outputs the connection endpoints for the Neo4j Browser and Bolt protocol:

```
Neo4j HTTP (Browser): http://<LOAD_BALANCER_IP>:7474
Neo4j Bolt:           bolt://<LOAD_BALANCER_IP>:7687
```

---

## Connecting to Your Cluster

Connect `kubectl` to the newly provisioned AKS cluster:

```bash
az aks get-credentials --resource-group <RESOURCE_GROUP_NAME> --name <CLUSTER_NAME>
```

Verify the operator and database pods:

```bash
# Check the Neo4j Operator
kubectl get pods -n neo4j-operator-system

# Check the Neo4j cluster instances
kubectl get pods -l app.kubernetes.io/name=neo4j

# View custom resource status
kubectl get neo4j
```

---

## Deleting Your Deployment

To delete the cluster and all associated resources created by the template:

```bash
az group delete --yes --name <RESOURCE_GROUP_NAME>
```

---

## Troubleshooting & Logs

If the Neo4j Browser does not load or you need to inspect cluster health:

1. **Check Operator Logs**:
   ```bash
   kubectl logs -n neo4j-operator-system -l app.kubernetes.io/name=neo4j-operator -f
   ```

2. **Check Neo4j Database Logs**:
   ```bash
   kubectl logs -l app.kubernetes.io/name=neo4j -c neo4j -f
   ```

3. **Check Custom Resource Events**:
   ```bash
   kubectl describe neo4j <INSTANCE_NAME>
   ```

---

## Azure Marketplace Packaging

To package the ARM template and UI definition for Microsoft Partner Center:

```bash
./marketplace/package.sh
```

This generates `dist/neo4j-kubernetes-operator-marketplace.zip` ready for upload as an Azure Application (Solution Template) offer in Microsoft Partner Center.
