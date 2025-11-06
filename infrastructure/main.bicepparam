using './main.bicep'

param clusterName = 'aks-argocd-prod'
param location = 'eastus'
param dnsPrefix = 'aks-argocd-prod'
param enableAzureRBAC = true
param kubernetesVersion = '1.28.3'
param tags = {
  environment: 'production'
  managedBy: 'ArgoCD'
  project: 'GitOps'
  costCenter: 'IT'
}
