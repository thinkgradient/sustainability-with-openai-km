@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length.')
@minLength(2)
@maxLength(60)
param global_prefix string
param name string
param kvName string


/*
  Reference existing Key Vault
*/

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: kvName
}


/*
  Create Azure Search Service
*/

param search_name string = '${global_prefix}-${name}-${substring(uniqueString(resourceGroup().id), 0,3)}'


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
  Create Azure Storage account and container
*/
param storageName string 
param containerName string 
param videoContainerName string 
param videoContainerSource string 

param storageAccountName string = '${global_prefix}${storageName}${substring(uniqueString(resourceGroup().id), 0,3)}'

module deployStorageAccount './modules/storage-account.bicep' = {
  name: 'DeployStorageAccount-${storageAccountName}'
  params: {
    storageName: storageAccountName
    global_prefix: global_prefix
    containerName: containerName
    videoContainerName: videoContainerName
    videoContainerSource: videoContainerSource
  }
}


/*
  Create Azure KeyVault secrets
*/

param container_url string = 'https://${storageAccountName}.blob.core.windows.net/${containerName}?'

resource containerSasUrl 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'container-sas-url'
  properties: {
    value: '${container_url}${deployStorageAccount.outputs.myContainerUploadSAS}'
  }
}

param openaiapikey string

resource openaiApiKey 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'openai-api-key'
  properties: {
    value: '${openaiapikey}'
  }
}

param openaiapitype string

resource openaiApiType 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'openai-api-type'
  properties: {
    value: '${openaiapitype}'
  }
}

param openaiapibase string

resource openaiApiBase 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'openai-api-base'
  properties: {
    value: '${openaiapibase}'
  }
}

param openaiapiversion string

resource openaiApiVersion 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'openai-api-version'
  properties: {
    value: '${openaiapiversion}'
  }
}

/*
  Create User Assigned Identity  
*/
param userAssignedIdentityName string = 'userid'
param userAssignedMangedIdentityName string = '${global_prefix}${userAssignedIdentityName}${substring(uniqueString(resourceGroup().id), 0,3)}id'


resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: userAssignedMangedIdentityName
  location: location

}

/*
  Deploy Video Indexer service
*/

param videoIndexName string 

module deployVideoIndexer './modules/video-indexer.bicep' = {
  name: 'deployVideoIndexer-${videoIndexName}'
  params: {
    global_prefix: global_prefix
    videoAccountName: videoIndexName
    location: location
    storageAccountId: '${deployStorageAccount.outputs.storageAccountId}'
    userAssignedIdentityPrincipalId: '${userAssignedIdentity.properties.principalId}'
    userAssignedIdentityId: '${userAssignedIdentity.id}'
  }
}





/*
  Create five Azure App Functions - PDFSplitter, SDGSimilarity, OpenAIHTTPTrigger, Start Video Indexing, VideoCallBack
  Note: You still need to deploy the function code using VSCode or Azure CLI
*/

param appName array
param appInsightsLocation string
param runtime string

param search_api_version string
param search_index string




module deployAIFunctions './modules/ai-functions.bicep' = [for funcname in appName: {
  name: 'DeployFunction-${funcname}'
  params: {
    appName: '${global_prefix}-${funcname}-${substring(uniqueString(resourceGroup().id), 0,3)}'
    appInsightsLocation: appInsightsLocation
    runtime: runtime
    global_prefix: global_prefix
    storageName: storageAccountName
    videoContainerName: videoContainerName
    videoContainerSource: videoContainerSource
    container_sas_url: '${container_url}${deployStorageAccount.outputs.myContainerUploadSAS}'
    blobAccountKey: '${deployStorageAccount.outputs.blobAccountKey}'

    openai_api_key: openaiapikey
    openai_api_type: openaiapitype
    openai_api_base: openaiapibase
    openai_api_version: openaiapiversion

    search_name: search_name
    search_api_key: '${listAdminKeys('${resourceId('Microsoft.Search/searchServices', '${search_name}')}', '2015-08-19').PrimaryKey}'
    search_api_version: '${search_api_version}'
    search_index: '${search_index}'

    video_indexer_account_id: '${deployVideoIndexer.outputs.videoIndexAccountId}'
    video_indexer_api_key: ''
    video_indexer_endpoint: 'https://api.videoindexer.ai'
    video_indexer_location: '${location}'
    video_indexer_location_url_prefix: 'www'
    video_indexer_resource_id: '${deployVideoIndexer.outputs.videoIndexerResourceId}'

    userAssignedIdentityPrincipalId: '${userAssignedIdentity.properties.principalId}'
    userAssignedIdentityId: '${userAssignedIdentity.id}'

  }
}]

/*
  Create Event Grid to fetch documents 
*/

param systemTopicName string = 'videoTopic'

resource systemTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: systemTopicName
  location: location
  dependsOn: [
    deployAIFunctions
  ] 
  properties: {
    source: '${deployStorageAccount.outputs.storageAccountId}'
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

param systemTopicSub string = 'videoTopic/videoSubtopic'

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = {
  name: systemTopicSub
  dependsOn: [
    systemTopic
  ] 
  properties: {
    destination: {
      properties: {
        resourceId: resourceId('Microsoft.Web/sites/functions/', '${global_prefix}-videoindexer-${substring(uniqueString(resourceGroup().id), 0,3)}-f4', 'start-video-indexing')
      }
      endpointType: 'AzureFunction'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
      subjectBeginsWith: '/blobServices/default/containers/video-knowledge-mining-drop/'
    }
  }
}

/*
  Deploy Container Registry
*/



param uniquestring string = '${uniqueString(resourceGroup().id)}'
var acrName = '${global_prefix}acr${substring(uniqueString(resourceGroup().id), 0,3)}'

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
  Deploy App Service (Website) with Container Registry deployment
*/

param webAppName string 
param dockerImage string

param webAppNameService string = '${global_prefix}${webAppName}${substring(uniqueString(resourceGroup().id), 0,3)}'

module deployAppService './modules/app-service-ui.bicep' = {
  name: 'DeployAppService-${webAppNameService}'
  params: {
    acrName: acrName
    global_prefix: global_prefix
    appName: webAppNameService
    storageName: storageAccountName
    dockerImageName: dockerImage
  }
  dependsOn: [
    acrResource
  ]
}


/*
   Assign Acr Pull role to Web App on Container Registry
*/

param builtInRoleType string = 'Contributor'
var webappid = '${deployAppService.outputs.appServiceManagedIdentity}'


var roleDefinitionId = {
  Owner: {
    id: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8e3af657-a8ff-443c-a75c-2fe8c4bcb635')
  }
  Contributor: {
    id: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
  }
  Reader: {
    id: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
  }
}

resource assignAcrPulltoWebApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, acrResource.name, 'AssignAcrPullToWebApp', '${substring(uniqueString(resourceGroup().id), 0,3)}')   
  scope: acrResource
  properties: {
    description: 'Assign AcrPull role to Web App'
    principalId: webappid
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId[builtInRoleType].id
  }

}

/*
  Create Container Registry WebHook that pushes image to Web App 
*/

// var appServieNameOutput = deployAppService.outputs.appserviceAppName

// param apppublishingcreds string = '${appServieNameOutput}/publishingcredentials'
 


resource publishingcreds 'Microsoft.Web/sites/config@2022-03-01' existing = {
  name: '${webAppNameService}/publishingcredentials'
}

var creds = list(publishingcreds.id, publishingcreds.apiVersion).properties.scmUri

resource hook 'Microsoft.ContainerRegistry/registries/webhooks@2020-11-01-preview' = {
  parent: acrResource
  location: location
  name: 'webhook1' 
  properties: {
    serviceUri: '${creds}/api/registry/webhook'
    status: 'enabled'
  
    actions: [
      'push'
    ]
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



