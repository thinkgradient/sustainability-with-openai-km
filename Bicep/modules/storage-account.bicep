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

// var sasConfig = {

//   canonicalizedResource: '/blob/${storageAccount.name}/${containersDocuments.name}'
//   signedResource: 'c'
//   signedStart: '2023-01-28T00:00:00Z'
//   signedPermission: 'racwl'
//   signedExpiry: '2023-12-30T00:00:00Z'
//   signedProtocol: 'https'
//   keyToSign: 'key1'
// }
// output myContainerUploadSAS string = storageAccount.listServiceSas(storageAccount.apiVersion, sasConfig).serviceSasToken


// output myContainerUploadSAS string = listServiceSAS(storageAccount.name,'2022-09-01', {
//   canonicalizedResource: '/blob/${storageAccount.name}/${containersDocuments.name}'
//   signedResource: 'c'
//   signedProtocol: 'https'
//   signedPermission: 'racwl'
//   signedExpiry: '2023-12-30'
//   keyToSign: 'key1'
// }).serviceSasToken

output blobAccountKey string = '${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
output containerNameStr string = '${containerName}'
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'