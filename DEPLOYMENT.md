# Deployment Guide

This comprehensive guide covers the complete deployment process for the AKS + ArgoCD GitOps system.

## Prerequisites

### Required Tools
- **Azure CLI**: v2.50.0 or later
- **kubectl**: v1.28.0 or later
- **Helm**: v3.12.0 or later
- **Git**: v2.40.0 or later

### Azure Requirements
- Active Azure subscription
- Permissions to create:
  - Resource Groups
  - AKS clusters
  - Managed Identities
  - Network resources

### GitHub Requirements
- GitHub account with repository access
- Personal Access Token (PAT) with `repo` scope

## Installation Steps

### Phase 1: Azure Infrastructure Setup

#### 1.1 Login and Set Subscription

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "<subscription-id>"

# Verify
az account show
```

#### 1.2 Create Resource Group

```bash
# Set variables
RESOURCE_GROUP="rg-aks-argocd-prod"
LOCATION="eastus"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags Environment=Production Project=GitOps ManagedBy=ArgoCD
```

#### 1.3 Deploy AKS Cluster

```bash
# Navigate to infrastructure directory
cd infrastructure

# Validate Bicep template
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.bicepparam

# Deploy AKS cluster (takes 10-15 minutes)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --name aks-deployment-$(date +%Y%m%d-%H%M%S)

# Get deployment outputs
az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name <deployment-name> \
  --query properties.outputs
```

#### 1.4 Connect to AKS Cluster

```bash
# Get cluster name from deployment
CLUSTER_NAME=$(az aks list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Get credentials
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --overwrite-existing

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Phase 2: ArgoCD Installation

#### 2.1 Create ArgoCD Namespace

```bash
# Apply namespace
kubectl apply -f argocd/namespace.yaml

# Verify
kubectl get namespace argocd
```

#### 2.2 Install ArgoCD via Helm

```bash
# Add Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Review values
cat argocd/values.yaml

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --values argocd/values.yaml \
  --version 5.51.0 \
  --wait

# Verify installation
helm list -n argocd
kubectl get pods -n argocd
```

#### 2.3 Wait for ArgoCD Components

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  --all -n argocd \
  --timeout=600s

# Check status
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### Phase 3: ArgoCD Configuration

#### 3.1 Access ArgoCD UI

```bash
# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"

# Port forward (run in separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
# Username: admin
# Password: $ARGOCD_PASSWORD
```

#### 3.2 Install ArgoCD CLI (Optional)

```bash
# For Linux/macOS
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd
rm argocd

# For Windows (PowerShell)
# Download from: https://github.com/argoproj/argo-cd/releases/latest

# Verify installation
argocd version
```

#### 3.3 Login to ArgoCD CLI

```bash
# Login (with port-forward running)
argocd login localhost:8080 \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure

# Or login with server name (if using ingress)
argocd login argocd.example.com \
  --username admin \
  --password $ARGOCD_PASSWORD
```

#### 3.4 Change Admin Password

```bash
# Update password
argocd account update-password \
  --current-password $ARGOCD_PASSWORD \
  --new-password <new-secure-password>

# Store securely (e.g., Azure Key Vault)
```

### Phase 4: Repository Configuration

#### 4.1 Generate GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name: "ArgoCD GitOps"
4. Select scopes: `repo` (full control of private repositories)
5. Generate and copy the token

#### 4.2 Add Repository to ArgoCD

```bash
# Set variables
GITHUB_REPO="https://github.com/comeredon/AKSPE"
GITHUB_USERNAME="comeredon"
GITHUB_TOKEN="<your-github-token>"

# Add repository via CLI
argocd repo add $GITHUB_REPO \
  --username $GITHUB_USERNAME \
  --password $GITHUB_TOKEN \
  --insecure-skip-server-verification

# Verify repository connection
argocd repo list

# Or add via UI:
# Settings → Repositories → Connect Repo
# - Repository URL: https://github.com/comeredon/AKSPE
# - Username: your-username
# - Password: your-token
```

#### 4.3 Update Repository URL in Manifests

```bash
# Update root-application.yaml with your repository URL
sed -i 's|https://github.com/comeredon/pl1ref|'"$GITHUB_REPO"'|g' argocd/root-application.yaml

# Commit the change
git add argocd/root-application.yaml
git commit -m "Update repository URL"
git push
```

### Phase 5: Deploy Root Application

#### 5.1 Apply Root Application

```bash
# Apply the root application
kubectl apply -f argocd/root-application.yaml

# Verify application
kubectl get application -n argocd

# Check application status
argocd app get namespace-manager

# View in UI
# https://localhost:8080/applications/namespace-manager
```

#### 5.2 Sync Application

```bash
# Manual sync (if not auto-syncing)
argocd app sync namespace-manager

# Wait for sync to complete
argocd app wait namespace-manager --timeout 300

# Check sync status
argocd app get namespace-manager
```

### Phase 6: Verification

#### 6.1 Verify ArgoCD Application

```bash
# Check application health
argocd app get namespace-manager --show-operation

# List all applications
argocd app list

# Expected output:
# NAME               CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH
# namespace-manager  https://kubernetes.default.svc  argocd     default  Synced  Healthy
```

#### 6.2 Verify Example Namespace

```bash
# Check if example namespace was created
kubectl get namespace example-namespace

# View namespace details
kubectl get namespace example-namespace -o yaml

# Check resources in namespace
kubectl get resourcequota -n example-namespace
kubectl get limitrange -n example-namespace
kubectl get networkpolicy -n example-namespace
```

#### 6.3 Test Namespace Creation

```bash
# Create a test namespace
cat > namespaces/test-namespace.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: test-namespace
  labels:
    managed-by: argocd
    environment: test
    team: platform
  annotations:
    description: "Test namespace for validation"
EOF

# Commit and push
git add namespaces/test-namespace.yaml
git commit -m "Add test namespace"
git push

# Wait for ArgoCD to sync (auto-sync should pick it up)
sleep 30

# Verify namespace was created
kubectl get namespace test-namespace
```

### Phase 7: Configure GitHub Actions

#### 7.1 Review Workflow Files

```bash
# Check PR validation workflow
cat .github/workflows/namespace-pr-validation.yaml

# Check notification workflow
cat .github/workflows/namespace-notification.yaml
```

#### 7.2 Test PR Workflow

```bash
# Create a branch for testing
git checkout -b test-pr-workflow

# Create a new namespace
cp namespaces/example-namespace.yaml namespaces/pr-test-namespace.yaml
sed -i 's/example-namespace/pr-test-namespace/g' namespaces/pr-test-namespace.yaml

# Commit and push
git add namespaces/pr-test-namespace.yaml
git commit -m "Test PR workflow"
git push origin test-pr-workflow

# Create PR on GitHub and observe:
# 1. Validation checks run automatically
# 2. Comments are added to PR
# 3. After merge, notification is created
```

#### 7.3 Configure Slack Notifications (Optional)

```bash
# If you have a Slack webhook URL:
# 1. Go to GitHub repository → Settings → Secrets and variables → Actions
# 2. Add new secret: SLACK_WEBHOOK_URL
# 3. Paste your Slack webhook URL

# Test the notification:
# Merge a PR and check Slack channel for notification
```

### Phase 8: Production Hardening

#### 8.1 Configure RBAC

```bash
# Create namespace admin role
kubectl create clusterrole namespace-admin \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=namespaces,resourcequotas,limitranges

# Bind to user/group
kubectl create clusterrolebinding namespace-admin-binding \
  --clusterrole=namespace-admin \
  --user=<user-email>
```

#### 8.2 Enable Monitoring

```bash
# Verify container insights
kubectl get ds -n kube-system

# Check ArgoCD metrics
kubectl get servicemonitor -n argocd
```

#### 8.3 Configure Backup

```bash
# Install Velero for backup (optional)
# See: https://velero.io/docs/
```

#### 8.4 Set Up Ingress (Optional)

```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace

# Configure DNS and TLS
# Update argocd/values.yaml with ingress configuration
```

## Post-Deployment Checklist

- [ ] AKS cluster deployed and accessible
- [ ] ArgoCD installed and running
- [ ] ArgoCD UI accessible
- [ ] Repository connected to ArgoCD
- [ ] Root application deployed and synced
- [ ] Example namespace created automatically
- [ ] GitHub Actions workflows functioning
- [ ] Test PR created and validated
- [ ] Notifications configured (if using)
- [ ] Admin password changed and stored securely
- [ ] RBAC configured
- [ ] Monitoring enabled
- [ ] Documentation reviewed

## Troubleshooting

### ArgoCD pods not starting

```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Repository connection fails

```bash
# Check repository credentials
argocd repo list

# Test connectivity
kubectl exec -n argocd <argocd-server-pod> -- \
  git ls-remote $GITHUB_REPO
```

### Application not syncing

```bash
# Check application status
argocd app get namespace-manager

# View events
kubectl describe application namespace-manager -n argocd

# Manual sync
argocd app sync namespace-manager --force
```

### Namespace not created

```bash
# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check resource status
kubectl get events -n argocd
```

## Rollback Procedures

### Rollback Application

```bash
# List application history
argocd app history namespace-manager

# Rollback to specific revision
argocd app rollback namespace-manager <revision-id>
```

### Rollback Infrastructure

```bash
# List deployments
az deployment group list --resource-group $RESOURCE_GROUP

# Rollback to previous deployment (requires saved template)
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file <previous-template>
```

## Next Steps

1. Review [README.md](README.md) for usage information
2. Create your first production namespace
3. Configure notifications and alerts
4. Set up CI/CD pipelines
5. Implement backup strategy
6. Configure disaster recovery

## Support

For issues or questions:
- Check ArgoCD documentation: https://argo-cd.readthedocs.io/
- Open GitHub issue
- Contact platform team

---

**Deployment Complete! 🎉**
