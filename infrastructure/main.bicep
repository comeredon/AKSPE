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
param kubernetesVersion string = '1.28.3'

@description('Tags to apply to resources')
param tags object = {
  environment: 'production'
  managedBy: 'ArgoCD'
  project: 'GitOps'
}

// Deploy AKS cluster using Azure Verified Module
module aksCluster 'br/public:avm/res/container-service/managed-cluster:0.5.0' = {
  name: 'aksClusterDeployment'
  params: {
    name: clusterName
    location: location
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    
    // Enable system-assigned managed identity
    managedIdentities: {
      systemAssigned: true
    }
    
    // Enable Azure AD integration with RBAC
    aadProfile: {
      aadProfileManaged: true
      aadProfileEnableAzureRBAC: enableAzureRBAC
    }
    
    // Primary agent pool configuration
    primaryAgentPoolProfiles: [
      {
        name: 'systempool'
        count: 3
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        enableAutoScaling: true
        minCount: 3
        maxCount: 5
        maxPods: 110
        osDiskSizeGB: 128
        osDiskType: 'Managed'
      }
    ]
    
    // Network configuration
    networkPlugin: 'azure'
    networkPolicy: 'azure'
    enableRBAC: true
    
    // Security features
    disableLocalAccounts: true
    enableAzureDefender: true
    
    // Monitoring
    omsAgentEnabled: true
    enableContainerInsights: true
    
    // Tags
    tags: tags
  }
}

// Outputs
output clusterName string = aksCluster.outputs.name
output clusterResourceId string = aksCluster.outputs.resourceId
output kubeletIdentityObjectId string = aksCluster.outputs.kubeletIdentityObjectId
output controlPlaneFQDN string = aksCluster.outputs.controlPlaneFQDN
output resourceGroupName string = resourceGroup().name
