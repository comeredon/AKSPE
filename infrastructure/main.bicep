targetScope = 'resourceGroup'

@description('Name of the AKS cluster')
param clusterName string = 'aks-argocd-cluster'

@description('Location for all resources')
param location string = resourceGroup().location

@description('DNS prefix for the cluster')
param dnsPrefix string = 'aks-argocd'

@description('Enable Azure RBAC for Kubernetes authorization')
param enableAzureRBAC bool = true

@description('Kubernetes version')
param kubernetesVersion string = '1.30'

@description('Tags to apply to resources')
param tags object = {
  environment: 'production'
  managedBy: 'ArgoCD'
  project: 'GitOps'
}

// Deploy AKS cluster directly
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    disableLocalAccounts: true
    
    aadProfile: {
      managed: true
      enableAzureRBAC: enableAzureRBAC
    }
    
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: 3
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        osType: 'Linux'
        enableAutoScaling: true
        minCount: 3
        maxCount: 5
        maxPods: 110
        osDiskSizeGB: 128
        type: 'VirtualMachineScaleSets'
      }
    ]
    
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
  }
}

// Outputs
output clusterName string = aksCluster.name
output clusterResourceId string = aksCluster.id
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId
output controlPlaneFQDN string = aksCluster.properties.fqdn
output resourceGroupName string = resourceGroup().name
