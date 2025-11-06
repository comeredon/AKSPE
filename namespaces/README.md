# Namespace Template

Copy this template to create a new namespace. Replace `NAMESPACE_NAME` with your desired namespace name.

## Template Structure

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: NAMESPACE_NAME
  labels:
    managed-by: argocd
    environment: production  # or development, staging
    team: YOUR_TEAM_NAME
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    description: "Brief description of namespace purpose"
    created-by: "GitOps PR Process"
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: NAMESPACE_NAME
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    services.loadbalancers: "2"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: namespace-limits
  namespace: NAMESPACE_NAME
spec:
  limits:
  - max:
      cpu: "4"
      memory: 8Gi
    min:
      cpu: 100m
      memory: 128Mi
    default:
      cpu: 500m
      memory: 1Gi
    defaultRequest:
      cpu: 100m
      memory: 256Mi
    type: Container
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: NAMESPACE_NAME
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

## Creating a New Namespace via PR

1. **Copy the template**: Create a new file in the `namespaces/` directory with the name `<namespace-name>.yaml`
2. **Replace placeholders**: Update all occurrences of `NAMESPACE_NAME` and other placeholders
3. **Customize resources**: Adjust ResourceQuota and LimitRange values based on your needs
4. **Create a Pull Request**: Submit your changes via PR
5. **Review and Merge**: Once approved and merged, ArgoCD will automatically create the namespace
6. **Verify**: Check ArgoCD UI for sync status and any notifications

## Resource Quota Guidelines

- **Development**: 5 CPU, 10Gi Memory
- **Staging**: 10 CPU, 20Gi Memory  
- **Production**: 20 CPU, 40Gi Memory (or more based on needs)

## Network Policy

The default template includes a deny-all network policy. You'll need to add specific policies to allow required traffic.

## Questions?

Contact the platform team or open an issue in this repository.
