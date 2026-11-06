# Azure Marketplace Packaging

This directory contains packaging tooling to prepare the Neo4j Kubernetes Operator ARM template for publication as an **Azure Application (Solution Template)** offer in **Microsoft Partner Center**.

---

## Build the Marketplace Package

Run the packaging script from the root of the repository or from this directory:

```bash
./marketplace/package.sh
```

The script performs the following actions:
1. **Validates JSON Syntax**: Checks `ee/mainTemplate.json` and `ee/createUiDefinition.json`.
2. **Cross-Checks Parameters**: Ensures that all UI outputs declared in `createUiDefinition.json` map cleanly to the input parameters defined in `mainTemplate.json`.
3. **Creates the Distribution Zip**: Bundles `mainTemplate.json` and `createUiDefinition.json` into:
   ```
   dist/neo4j-kubernetes-operator-marketplace.zip
   ```
4. **Calculates SHA-256 Checksum**: Outputs the package checksum for verification during Partner Center upload.

---

## Uploading to Microsoft Partner Center

1. Sign in to [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview).
2. Create or open your **Azure Application** offer.
3. Under **Plan overview**, select or create your **Solution template** plan.
4. In the **Technical configuration** blade, upload `dist/neo4j-kubernetes-operator-marketplace.zip`.
5. Save the draft and proceed to **Review and publish** for preview testing.

