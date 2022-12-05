@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length.')
@minLength(2)
@maxLength(60)
param global_prefix string
param name string

param search_name string = '${global_prefix}-${name}'

@allowed([
  'free'
  'basic'
  'standard'
  'standard2'
  'standard3'
  'storage_optimized_l1'
  'storage_optimized_l2'
])
@description('The pricing tier of the search service you want to create (for example, basic or standard).')
param sku string = 'standard'

@description('Replicas distribute search workloads across the service. You need at least two replicas to support high availability of query workloads (not applicable to the free tier).')
@minValue(1)
@maxValue(12)
param replicaCount int = 1

@description('Partitions allow for scaling of document count as well as faster indexing by sharding your index over multiple search units.')
@allowed([
  1
  2
  3
  4
  6
  12
])
param partitionCount int = 1

@description('Applicable only for SKUs set to standard3. You can set this property to enable a single, high density partition that allows up to 1000 indexes, which is much higher than the maximum indexes allowed for any other SKU.')
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'

@description('Location for all resources.')
param location string = resourceGroup().location

resource search 'Microsoft.Search/searchServices@2020-08-01' = {
  name: search_name
  location: location
  sku: {
    name: sku
  }
  properties: {
    replicaCount: replicaCount
    partitionCount: partitionCount
    hostingMode: hostingMode
  }
}

/*
  Storage Account 
*/

param rgLocation string = resourceGroup().location
param storageName string
param containerName string 

// Create storages
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: '${global_prefix}${storageName}'
  location: rgLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Create container
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' =  {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

/*
  Reference existing Key Vault
*/

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvName
}


/*
  Create three Azure App Functions - PDFSplitter, SDGSimilarity, and OpenAI
  Note: You still need to deploy the function code using VSCode or Azure CLI
*/

param kvName string
param appName array
param appInsightsLocation string
param runtime string


module deployAIFunctions './modules/ai-functions.bicep' = [for funcname in appName: {
  name: 'DeployFunction-${funcname}'
  params: {
    appName: '${global_prefix}-${funcname}'
    appInsightsLocation: appInsightsLocation
    runtime: runtime
    global_prefix: global_prefix
    storageName: storageName
    container_sas_url: kv.getSecret('container-sas-url')
    openai_api_key: kv.getSecret('openai-api-key')
    openai_api_type: kv.getSecret('openai-api-type')
    openai_api_base: kv.getSecret('openai-api-base')
    openai_api_version: kv.getSecret('openai-api-version')
  }
}]


/*
  Deploy Container Registry
*/

param webAppName string

param uniquestring string = '${uniqueString(resourceGroup().id)}'
var acrName = 'airliftacr${substring(uniquestring, 0, 2)}'

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Standard'

resource acrResource 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: true
  }
}



/*
  Deploy App Service (Website) with Container Register deployment
*/

module deployAppService './modules/app-service-ui.bicep' = {
  name: 'DeployAppService-${webAppName}'
  params: {
    acrName: acrName
    global_prefix: global_prefix
    appName: webAppName
    storageName: storageName
  }
}


/*
  Deploy generic Cognitive Services service for Azure Search skillset
*/

param cogserviceName string 

module deployCognitiveService './modules/cog-service.bicep' = {
  name: 'deployCognitiveService-${cogserviceName}'
  params: {
    global_prefix: global_prefix
    serviceName: cogserviceName
  }
}

