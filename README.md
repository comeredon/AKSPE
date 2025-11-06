# AKS with ArgoCD GitOps - Namespace Management

This repository provides a complete setup for managing Kubernetes namespaces on Azure Kubernetes Service (AKS) using ArgoCD for GitOps.

## 🎯 Overview

This project implements a GitOps workflow where:
1. **Developers** create namespace requests via Pull Requests
2. **GitHub Actions** validates the namespace configuration automatically
3. **ArgoCD** watches the repository and creates namespaces when PRs are merged
4. **Notifications** are sent when namespaces are successfully created

## 📁 Repository Structure

```
.
├── infrastructure/          # AKS cluster deployment (Bicep)
│   ├── main.bicep          # Main Bicep template
│   └── main.bicepparam     # Parameters file
├── argocd/                 # ArgoCD installation and configuration
│   ├── namespace.yaml      # ArgoCD namespace
│   ├── values.yaml         # Helm values
│   ├── root-application.yaml  # Root ArgoCD Application
│   └── README.md           # ArgoCD setup instructions
├── namespaces/             # Namespace definitions (managed by ArgoCD)
│   ├── example-namespace.yaml  # Example namespace template
│   └── README.md           # Namespace creation guide
└── .github/
    └── workflows/          # GitHub Actions workflows
        ├── namespace-pr-validation.yaml    # PR validation
        └── namespace-notification.yaml     # Post-merge notifications
```

**Repository:** https://github.com/comeredon/AKSPE

## 🚀 Getting Started

### Prerequisites

- Azure subscription
- Azure CLI installed and configured
- kubectl installed
- Helm 3.x installed
- Git and GitHub account
- Permissions to create resources in Azure

### Step 1: Deploy AKS Cluster

```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-aks-argocd --location eastus

# Deploy AKS cluster using Bicep
az deployment group create \
  --resource-group rg-aks-argocd \
  --template-file infrastructure/main.bicep \
  --parameters infrastructure/main.bicepparam

# Get cluster credentials
az aks get-credentials \
  --resource-group rg-aks-argocd \
  --name aks-argocd-prod
```

### Step 2: Install ArgoCD

```bash
# Create ArgoCD namespace
kubectl apply -f argocd/namespace.yaml

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd/values.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 3: Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward to access UI (in a separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 4: Configure Repository in ArgoCD

```bash
# Install ArgoCD CLI (optional but recommended)
# For Linux/macOS:
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login to ArgoCD
argocd login localhost:8080

# Add your repository (replace with your repo URL)
argocd repo add https://github.com/comeredon/pl1ref \
  --username <your-github-username> \
  --password <your-github-token>
```

### Step 5: Deploy Root Application

```bash
# Update root-application.yaml with your repository URL
# Then apply it
kubectl apply -f argocd/root-application.yaml

# Verify the application
kubectl get applications -n argocd
```

### Step 6: Configure GitHub Secrets (Optional)

For Slack notifications, add these secrets to your GitHub repository:

- `SLACK_WEBHOOK_URL`: Your Slack webhook URL

Go to: Repository Settings → Secrets and variables → Actions → New repository secret

## 📝 Creating a New Namespace

### Method 1: Using the Template (Recommended)

1. **Copy the template** from `namespaces/example-namespace.yaml`
2. **Create a new file** in the `namespaces/` directory (e.g., `namespaces/my-team-dev.yaml`)
3. **Replace all occurrences** of namespace name and customize:
   - Namespace name
   - Labels (team, environment)
   - Resource quotas
   - Limit ranges
4. **Create a Pull Request**
5. **Wait for validation** - GitHub Actions will automatically validate your configuration
6. **Get approval** from required reviewers
7. **Merge the PR** - ArgoCD will automatically create the namespace
8. **Check notifications** - You'll receive a notification issue when done

### Method 2: Manual Creation

```bash
# Create a new namespace file
cat > namespaces/my-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: my-namespace
  labels:
    managed-by: argocd
    environment: production
    team: my-team
  annotations:
    description: "My new namespace"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: my-namespace
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
EOF

# Commit and push
git add namespaces/my-namespace.yaml
git commit -m "Add my-namespace"
git push origin main
```

## 🔍 Validation Rules

GitHub Actions automatically validates:

✅ YAML syntax correctness
✅ Namespace naming convention (lowercase, alphanumeric, hyphens only)
✅ Namespace name length (max 63 characters)
✅ Required labels (`managed-by: argocd`)
✅ Team label presence
✅ ResourceQuota definitions
✅ Security best practices (via Kubesec)

## 📊 Monitoring and Troubleshooting

### Check ArgoCD Application Status

```bash
# List all applications
kubectl get applications -n argocd

# Get application details
kubectl describe application namespace-manager -n argocd

# View application logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Check Namespace Status

```bash
# List all namespaces
kubectl get namespaces

# Get detailed namespace info
kubectl get namespace <namespace-name> -o yaml

# Check resource quotas
kubectl get resourcequota -n <namespace-name>

# Check limit ranges
kubectl get limitrange -n <namespace-name>
```

### ArgoCD UI

Access the ArgoCD UI to:
- View sync status
- See application health
- Review sync history
- Trigger manual syncs
- View logs and events

## 🔐 Security Considerations

- **Network Policies**: Default deny-all policy is applied to all namespaces
- **Resource Quotas**: Prevent resource exhaustion
- **Limit Ranges**: Enforce pod-level resource constraints
- **RBAC**: Azure RBAC integration for cluster access
- **GitOps**: All changes tracked in Git for audit trail

## 🔄 Sync Policies

ArgoCD is configured with:
- **Auto-sync**: Automatically applies changes when detected
- **Self-heal**: Reverts manual changes to match Git state
- **Prune**: Removes resources deleted from Git

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [GitOps Principles](https://www.gitops.tech/)

## 🤝 Contributing

1. Fork the repository: https://github.com/comeredon/AKSPE
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📧 Support

For issues or questions:
- Open a GitHub issue
- Contact the platform team
- Check ArgoCD logs for sync errors

## 📜 License

This project is licensed under the MIT License.

---

**Built with ❤️ using GitOps principles**
