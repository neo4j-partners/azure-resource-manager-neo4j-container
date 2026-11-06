# Publishing the Neo4j Kubernetes Operator on Microsoft Azure Marketplace

This guide outlines the step-by-step workflow for publishing this repository as an **Azure Application (Solution Template)** offer in the **Microsoft Commercial Marketplace** via **Microsoft Partner Center**.

---

## 1. Prerequisites

Before starting, ensure you have:
1. An active **Microsoft Partner Center** account enrolled in the Commercial Marketplace program.
2. An active Azure subscription linked for billing and validation testing.
3. Marketing assets:
   - Solution description, summary, and search keywords.
   - Neo4j logos (48x48, 216x216, 255x115, 816x414 PNG format).
   - Screenshots of Neo4j Browser and AKS cluster topology.
   - Support URL and Privacy Policy URL.

---

## 2. Generate the Marketplace Deployment Package

Use the included packaging script to validate templates and create the distribution archive:

```bash
./scripts/package.sh
```

This creates the release package at:
`dist/neo4j-kubernetes-operator-marketplace.zip`

The archive contains:
- `mainTemplate.json` (ARM template defining AKS, Managed Identity, and Deployment Script)
- `createUiDefinition.json` (Azure Portal deployment wizard)
- `scripts/install-neo4j-operator.sh` (Post-deployment bootstrapping script)

---

## 3. Creating the Offer in Partner Center

### Step 3.1: Create New Offer
1. Sign in to [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview).
2. Navigate to **Commercial Marketplace** > **Overview**.
3. Click **+ New offer** > **Azure Application**.
4. Set an **Offer ID** (e.g. `neo4j-kubernetes-operator`) and **Offer alias**.

### Step 3.2: Offer Setup
- **Test drive**: Optional (leave disabled unless deploying a dedicated sandbox).
- **Customer leads**: Connect your CRM (Salesforce, Azure Table, or HTTPS endpoint) to receive customer deployment notifications.

### Step 3.3: Properties
- **Categories**: 
  - Primary: *Databases*
  - Secondary: *DevOps & Containers* / *Analytics*
- **Legal**: Provide your End User License Agreement (EULA) or check the standard Microsoft Commercial Marketplace Terms of Use.

### Step 3.4: Offer Listing
- Provide:
  - **Name**: `Neo4j Kubernetes Operator on Azure Kubernetes Service (AKS)`
  - **Search results summary**: Deploy and manage Neo4j graph databases on Azure Kubernetes Service using the official Kubernetes operator.
  - **Description**: Highlight features, clustering, enterprise backup, Neo4j Bloom, and Bloom/Browser integration.
  - **Icons and Screenshots**: Upload prepared PNG assets.
  - **Support Contact**: Support URL, email, and phone.

---

## 4. Configuring the Plan (Solution Template)

### Step 4.1: Create Plan
1. Under the **Plan overview** tab, select **+ Create new plan**.
2. **Plan ID**: `neo4j-aks-operator-plan`.
3. **Plan name**: `Neo4j Operator on AKS`.
4. **Plan type**: Select **Solution template**.
   > *Note: Solution templates deploy infrastructure directly into the customer's subscription without requiring publisher-managed tenant access.*

### Step 4.2: Technical Configuration
1. **Version**: e.g., `1.0.0`.
2. **Package file (.zip)**: Upload `dist/neo4j-kubernetes-operator-marketplace.zip`.
3. Once uploaded, Partner Center automatically validates:
   - The presence of `mainTemplate.json` and `createUiDefinition.json`.
   - Schema conformity and parameter bindings.

---

## 5. Preview & Testing

1. Once technical validation passes, navigate to the **Review and publish** tab.
2. In **Preview audience**, provide your Azure Subscription ID.
3. Click **Publish to Preview**.
4. Wait for the automated Microsoft certification and provisioning steps to complete (typically 1–3 hours).
5. Open the private preview link in the Azure Portal:
   - Verify the multi-step UI wizard (`createUiDefinition.json`).
   - Run a test deployment in your preview subscription.
   - Confirm AKS provisioning, operator Helm deployment, and Neo4j connectivity.

---

## 6. Going Live

1. After successful preview testing, return to Partner Center.
2. Click **Go Live** on the offer review blade.
3. Microsoft will perform final certification and push the listing to the public Azure Marketplace directory.

