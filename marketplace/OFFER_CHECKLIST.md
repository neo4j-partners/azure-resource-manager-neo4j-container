# Azure Marketplace Submission Checklist

Use this checklist before submitting the offer for Microsoft Marketplace certification.

## Technical Verification
- [x] `mainTemplate.json` passes schema validation.
- [x] `createUiDefinition.json` passes schema validation.
- [x] All outputs in `createUiDefinition.json` map directly to parameters in `mainTemplate.json`.
- [x] Deployment script uses a dedicated user-assigned managed identity with appropriate RBAC.
- [x] Deployment package builds cleanly with `./scripts/package.sh`.
- [x] Both Standalone and Cluster topology options are supported.
- [x] Parameter types and constraints (e.g. securestrings for passwords, regex for cluster names) are enforced.
- [x] AKS uses modern Kubernetes version (`1.30`) and CSI storage driver enabled.

## Partner Center Setup
- [ ] Active Commercial Marketplace publisher account.
- [ ] Offer type set to **Azure Application** with plan type **Solution Template**.
- [ ] Technical configuration package `dist/neo4j-kubernetes-operator-marketplace.zip` uploaded and verified.
- [ ] Support and Privacy URLs supplied.
- [ ] Terms of use / EULA linked.
- [ ] High-resolution logo assets uploaded (PNG, transparent background):
  - Small (48x48)
  - Medium (90x90)
  - Large (216x216)
  - Wide (255x115)
  - Hero (816x414)
- [ ] At least 1-3 screenshots showcasing Neo4j Browser and AKS status.
- [ ] Preview subscription ID configured for validation testing.

