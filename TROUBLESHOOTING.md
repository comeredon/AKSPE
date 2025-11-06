# Troubleshooting Guide

This guide covers common issues and their solutions for the AKS + ArgoCD GitOps system.

## Table of Contents
1. [AKS Cluster Issues](#aks-cluster-issues)
2. [ArgoCD Installation Issues](#argocd-installation-issues)
3. [Repository Connection Issues](#repository-connection-issues)
4. [Application Sync Issues](#application-sync-issues)
5. [Namespace Creation Issues](#namespace-creation-issues)
6. [GitHub Actions Issues](#github-actions-issues)
7. [Performance Issues](#performance-issues)

---

## AKS Cluster Issues

### Issue: Cannot connect to AKS cluster

**Symptoms:**
```bash
kubectl get nodes
# Error: Unable to connect to the server
```

**Solutions:**

1. **Verify credentials:**
```bash
az aks get-credentials \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --overwrite-existing
```

2. **Check cluster status:**
```bash
az aks show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query "powerState"
```

3. **Verify network connectivity:**
```bash
# Check if cluster is private
az aks show \
  --resource-group <resource-group> \
  --name <cluster-name> \
  --query "apiServerAccessProfile.enablePrivateCluster"
```

### Issue: Nodes not ready

**Symptoms:**
```bash
kubectl get nodes
# Shows nodes in NotReady state
```

**Solutions:**

1. **Check node status:**
```bash
kubectl describe node <node-name>
```

2. **Check system pods:**
```bash
kubectl get pods -n kube-system
```

3. **Restart kubelet (if needed):**
```bash
# Scale node pool down and up
az aks nodepool scale \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <nodepool-name> \
  --node-count 0

az aks nodepool scale \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --name <nodepool-name> \
  --node-count 3
```

---

## ArgoCD Installation Issues

### Issue: ArgoCD pods not starting

**Symptoms:**
```bash
kubectl get pods -n argocd
# Pods stuck in Pending or CrashLoopBackOff
```

**Solutions:**

1. **Check pod events:**
```bash
kubectl describe pod <pod-name> -n argocd
```

2. **Check logs:**
```bash
kubectl logs <pod-name> -n argocd
```

3. **Check resource availability:**
```bash
kubectl top nodes
kubectl describe node <node-name>
```

4. **Verify persistent volume claims:**
```bash
kubectl get pvc -n argocd
```

### Issue: Cannot access ArgoCD UI

**Symptoms:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Connection refused or timeout
```

**Solutions:**

1. **Check service status:**
```bash
kubectl get svc -n argocd
kubectl describe svc argocd-server -n argocd
```

2. **Check pod status:**
```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
```

3. **Use different port:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

4. **Check firewall rules:**
```bash
# Ensure port 8080 is not blocked locally
```

### Issue: Cannot retrieve admin password

**Symptoms:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret
# Secret not found
```

**Solutions:**

1. **Check if secret exists:**
```bash
kubectl get secrets -n argocd
```

2. **Reset admin password:**
```bash
# Generate new password
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | head -1)
kubectl exec -n argocd $ARGOCD_POD -- argocd admin initial-password
```

---

## Repository Connection Issues

### Issue: Cannot connect to GitHub repository

**Symptoms:**
```bash
argocd repo add https://github.com/user/repo
# Error: authentication failed
```

**Solutions:**

1. **Verify credentials:**
```bash
# Test GitHub token
curl -H "Authorization: token <your-token>" https://api.github.com/user
```

2. **Use HTTPS instead of SSH:**
```bash
# Use HTTPS URL
argocd repo add https://github.com/user/repo \
  --username <username> \
  --password <token>
```

3. **Check token permissions:**
- Token needs `repo` scope for private repositories
- Regenerate token with correct permissions

4. **Verify repository URL:**
```bash
# Test git clone
git clone https://<token>@github.com/user/repo.git /tmp/test
```

### Issue: Repository shows "Unknown" status

**Symptoms:**
```bash
argocd repo list
# Status shows "Unknown"
```

**Solutions:**

1. **Test connection:**
```bash
argocd repo get https://github.com/user/repo
```

2. **Check ArgoCD server logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

3. **Remove and re-add repository:**
```bash
argocd repo rm https://github.com/user/repo
argocd repo add https://github.com/user/repo --username <user> --password <token>
```

---

## Application Sync Issues

### Issue: Application stuck in "OutOfSync" state

**Symptoms:**
```bash
argocd app get namespace-manager
# Status: OutOfSync
```

**Solutions:**

1. **Check sync status:**
```bash
argocd app get namespace-manager --show-operation
```

2. **Manual sync:**
```bash
argocd app sync namespace-manager
```

3. **Force sync:**
```bash
argocd app sync namespace-manager --force
```

4. **Check application logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep namespace-manager
```

### Issue: Application shows "Degraded" health

**Symptoms:**
```bash
argocd app get namespace-manager
# Health Status: Degraded
```

**Solutions:**

1. **Check resource status:**
```bash
kubectl get all -n <namespace>
```

2. **View application details:**
```bash
argocd app get namespace-manager --show-operation
```

3. **Check events:**
```bash
kubectl get events -n argocd
```

4. **Refresh application:**
```bash
argocd app get namespace-manager --refresh
```

### Issue: Sync fails with permission errors

**Symptoms:**
```
Error: namespaces is forbidden: User "system:serviceaccount:argocd:argocd-application-controller" cannot create resource "namespaces"
```

**Solutions:**

1. **Check RBAC permissions:**
```bash
kubectl get clusterrolebinding -n argocd
```

2. **Grant permissions:**
```bash
kubectl create clusterrolebinding argocd-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd:argocd-application-controller
```

---

## Namespace Creation Issues

### Issue: Namespace not created after PR merge

**Symptoms:**
- PR merged successfully
- No namespace appears in cluster

**Solutions:**

1. **Check ArgoCD sync:**
```bash
argocd app get namespace-manager
argocd app sync namespace-manager
```

2. **Check application logs:**
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

3. **Verify file path:**
```bash
# Ensure namespace YAML is in namespaces/ directory
ls -la namespaces/
```

4. **Check YAML syntax:**
```bash
kubectl apply --dry-run=client -f namespaces/<namespace>.yaml
```

### Issue: ResourceQuota not applied

**Symptoms:**
```bash
kubectl get resourcequota -n <namespace>
# No resources found
```

**Solutions:**

1. **Check if ResourceQuota is in YAML:**
```bash
cat namespaces/<namespace>.yaml | grep -A 10 "kind: ResourceQuota"
```

2. **Apply manually:**
```bash
kubectl apply -f namespaces/<namespace>.yaml
```

3. **Check ArgoCD sync status:**
```bash
argocd app get namespace-manager --show-operation
```

### Issue: Network policy blocks all traffic

**Symptoms:**
- Pods cannot communicate
- Services unreachable

**Solutions:**

1. **Check network policies:**
```bash
kubectl get networkpolicy -n <namespace>
```

2. **Add allow policies:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
```

---

## GitHub Actions Issues

### Issue: PR validation workflow not running

**Symptoms:**
- PR created but no checks appear

**Solutions:**

1. **Check workflow file location:**
```bash
# Must be in .github/workflows/
ls -la .github/workflows/
```

2. **Check workflow syntax:**
```bash
# Use GitHub Actions validator
# Or install act: https://github.com/nektos/act
act -l
```

3. **Check branch protection rules:**
- Settings → Branches → Branch protection rules
- Ensure workflows are not blocked

### Issue: Workflow fails with permission errors

**Symptoms:**
```
Error: Resource not accessible by integration
```

**Solutions:**

1. **Check workflow permissions:**
```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

2. **Enable workflow permissions:**
- Settings → Actions → General → Workflow permissions
- Select "Read and write permissions"

### Issue: yq command not found

**Symptoms:**
```bash
yq: command not found
```

**Solutions:**

1. **Install yq in workflow:**
```yaml
- name: Install yq
  run: |
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
```

---

## Performance Issues

### Issue: Slow sync times

**Symptoms:**
- ArgoCD takes minutes to sync

**Solutions:**

1. **Increase timeout:**
```yaml
# In Application spec:
spec:
  syncPolicy:
    retry:
      limit: 5
      backoff:
        duration: 5s
        maxDuration: 5m
```

2. **Check resource limits:**
```bash
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

3. **Scale ArgoCD components:**
```bash
kubectl scale deployment argocd-repo-server -n argocd --replicas=2
kubectl scale deployment argocd-application-controller -n argocd --replicas=1
```

### Issue: High memory usage

**Symptoms:**
- ArgoCD pods being OOMKilled

**Solutions:**

1. **Increase resource limits:**
```yaml
# In values.yaml:
controller:
  resources:
    limits:
      memory: 2Gi
    requests:
      memory: 1Gi
```

2. **Upgrade ArgoCD:**
```bash
helm upgrade argocd argo/argo-cd -n argocd -f argocd/values.yaml
```

---

## Diagnostic Commands

### General Diagnostics

```bash
# Check all ArgoCD resources
kubectl get all -n argocd

# View ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Describe application
kubectl describe application namespace-manager -n argocd
```

### Application Diagnostics

```bash
# Get application status
argocd app get namespace-manager

# View sync history
argocd app history namespace-manager

# View application diff
argocd app diff namespace-manager

# List applications
argocd app list
```

### Cluster Diagnostics

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n argocd

# View cluster info
kubectl cluster-info
kubectl version
```

## Getting Help

If you're still experiencing issues:

1. **Check ArgoCD documentation**: https://argo-cd.readthedocs.io/en/stable/
2. **ArgoCD GitHub issues**: https://github.com/argoproj/argo-cd/issues
3. **Kubernetes documentation**: https://kubernetes.io/docs/
4. **Open an issue**: Create an issue at https://github.com/comeredon/AKSPE/issues with:
   - Description of the problem
   - Error messages
   - Output of diagnostic commands
   - ArgoCD version
   - Kubernetes version

## Emergency Contacts

- Platform Team: platform-team@example.com
- On-call: Check PagerDuty
- Slack: #platform-support

---

**Remember**: Always check logs first! Most issues can be diagnosed from ArgoCD logs.
