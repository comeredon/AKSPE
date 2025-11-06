# Quick Start Guide

This guide will help you get up and running quickly with the AKS + ArgoCD namespace management system.

## ⚡ 5-Minute Setup

### 1. Deploy Infrastructure (5 minutes)

```bash
# Clone the repository
git clone https://github.com/comeredon/AKSPE.git
cd AKSPE

# Login to Azure
az login

# Create resource group
az group create --name rg-aks-argocd --location eastus

# Deploy AKS (takes ~5 minutes)
az deployment group create \
  --resource-group rg-aks-argocd \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/main.bicepparam

# Connect to cluster
az aks get-credentials --resource-group rg-aks-argocd --name aks-argocd-prod
```

### 2. Install ArgoCD (2 minutes)

```bash
# Install ArgoCD
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd -n argocd -f argocd/values.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 3. Access ArgoCD (1 minute)

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward (in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser: https://localhost:8080
# Login with username: admin and the password from above
```

### 4. Configure Git Repository (2 minutes)

```bash
# In ArgoCD UI:
# Settings → Repositories → Connect Repo
# - Method: HTTPS
# - Repository URL: https://github.com/comeredon/AKSPE
# - Username: your-github-username  
# - Password: your-github-token

# OR via CLI:
argocd login localhost:8080
argocd repo add https://github.com/comeredon/AKSPE \
  --username <username> \
  --password <token>
```

### 5. Deploy Root Application (1 minute)

```bash
# Update the repoURL in argocd/root-application.yaml with your repository
# Then apply:
kubectl apply -f argocd/root-application.yaml
```

## ✅ Verify Installation

```bash
# Check ArgoCD applications
kubectl get applications -n argocd

# Should see: namespace-manager

# Check application status
argocd app get namespace-manager
```

## 🎉 Create Your First Namespace

### Option 1: Via GitHub PR (Recommended)

1. Create a new branch
```bash
git checkout -b add-my-first-namespace
```

2. Copy the example
```bash
cp namespaces/example-namespace.yaml namespaces/my-first-namespace.yaml
```

3. Edit the file and replace `example-namespace` with `my-first-namespace`

4. Commit and push
```bash
git add namespaces/my-first-namespace.yaml
git commit -m "Add my-first-namespace"
git push origin add-my-first-namespace
```

5. Create PR on GitHub

6. Once merged, check ArgoCD:
```bash
kubectl get namespace my-first-namespace
```

### Option 2: Direct (for testing)

```bash
# Edit and apply directly
kubectl apply -f namespaces/example-namespace.yaml

# Wait a moment, then check
kubectl get namespace example-namespace
```

## 🔍 Verify Everything Works

```bash
# 1. Check ArgoCD sync status
argocd app get namespace-manager

# 2. Verify namespace exists
kubectl get namespace

# 3. Check resource quotas
kubectl get resourcequota --all-namespaces

# 4. View ArgoCD UI
# Browser: https://localhost:8080
# Look for green "Synced" and "Healthy" status
```

## 🚨 Common Issues

### ArgoCD pods not starting
```bash
kubectl get pods -n argocd
kubectl describe pod <pod-name> -n argocd
```

### Repository connection fails
- Verify GitHub token has repo access
- Check if repository URL is correct
- Try re-adding the repository

### Namespace not created
- Check ArgoCD application sync status
- View application events: `argocd app get namespace-manager`
- Check for YAML syntax errors

## 📚 Next Steps

- [ ] Read the full [README.md](README.md)
- [ ] Review [ArgoCD documentation](argocd/README.md)
- [ ] Check [Namespace creation guide](namespaces/README.md)
- [ ] Configure notifications (optional)
- [ ] Set up RBAC permissions
- [ ] Configure backup strategy

## 💡 Pro Tips

1. **Use branches**: Always create PRs from branches, never commit directly to main
2. **Small changes**: Create one namespace per PR for easier review
3. **Descriptive names**: Use clear, descriptive names for namespaces
4. **Documentation**: Add good descriptions in the namespace annotations
5. **Monitor ArgoCD**: Regularly check the ArgoCD UI for sync issues

## 🆘 Getting Help

- **GitHub Issues**: [Create an issue](https://github.com/comeredon/pl1ref/issues)
- **ArgoCD Docs**: https://argo-cd.readthedocs.io/
- **Kubernetes Docs**: https://kubernetes.io/docs/

## 🎓 Learning Resources

- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)

---

**You're all set! 🚀**

Now you can manage Kubernetes namespaces through Git commits!
