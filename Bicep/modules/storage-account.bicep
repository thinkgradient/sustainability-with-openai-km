@description('This will create a storage account. (<name>-<resourceGroupName>)')
param rgLocation string = resourceGroup().location
param storageName string
param containerName string 
param videoContainerName string
param videoContainerSource string 
param global_prefix string 

// Create storages
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageName
  location: rgLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

output storageAccountId string = storageAccount.id

// Create documents container
resource containersDocuments 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' =  {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}
// Create video indexer container
resource containersVideo 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' =  {
  name: '${storageAccount.name}/default/${videoContainerName}'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

// Create video indexer container source (drop)
resource containersVideoSource 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' =  {
  name: '${storageAccount.name}/default/${videoContainerSource}'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

output myContainerUploadSAS string = listServiceSAS(storageAccount.name,'2021-04-01', {
  canonicalizedResource: '/blob/${storageAccount.name}/${containersDocuments.name}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'rwl'
  signedServices: 'b'
  signedExpiry: '2022-12-30T00:00:00Z'
}).serviceSasToken

output blobAccountKey string = '${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'