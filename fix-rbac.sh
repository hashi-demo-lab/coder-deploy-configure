#!/bin/bash

# Grant Coder service account permissions to manage workspace resources

echo "Creating RoleBinding for Coder service account in coder-workspaces namespace..."

kubectl create rolebinding coder-workspace-admin \
  --clusterrole=admin \
  --serviceaccount=coder:coder \
  --namespace=coder-workspaces

echo "Done! Coder can now create resources in coder-workspaces namespace."
