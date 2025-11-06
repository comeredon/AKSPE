# ArgoCD Installation using Helm

This directory contains the configuration for installing ArgoCD on the AKS cluster.

## Installation Steps

### 1. Connect to AKS Cluster
```bash
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
```

### 2. Create ArgoCD Namespace
```bash
kubectl apply -f namespace.yaml
```

### 3. Install ArgoCD using Helm
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --values values.yaml \
  --create-namespace
```

### 4. Access ArgoCD UI
```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access the UI at: https://localhost:8080
- Username: admin
- Password: (from the command above)

### 5. Configure Repository Access
```bash
# Add your GitHub repository
argocd repo add https://github.com/<your-org>/<your-repo> \
  --username <github-username> \
  --password <github-token>
```

### 6. Install Root Application
```bash
kubectl apply -f root-application.yaml
```

## Configuration

The `values.yaml` file contains customizations for:
- Azure AD integration
- RBAC configuration
- Notification settings
- Repository credentials
