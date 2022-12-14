@description('The name of the function app that you wish to create.')
param appName string 
param global_prefix string

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Location for Application Insights')
param appInsightsLocation string

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'java'
  'python'
])
param runtime string 
param storageName string
param blobAccountKey string
param videoContainerName string
param videoContainerSource string
param search_name string


var hostingPlanName = '${appName}'
var applicationInsightsName = '${appName}'
var storageAccountName = '${storageName}'
var functionWorkerRuntime = runtime



resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: storageAccountName
}

@secure()
param container_sas_url string


@secure()
param openai_api_key string 

@secure()
param openai_api_type string 

@secure()
param openai_api_base string 

@secure()
param openai_api_version string 


resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'S1'
  }
  properties: {
  	reserved: true
  }
}
var uniquestring = uniqueString(resourceGroup().id)
var uniquesuffix = substring(uniquestring, 0, 2)

resource functionAppPDFSplitter 'Microsoft.Web/sites@2021-03-01' = if (appName == '${global_prefix}-pdfsplitter-${substring(uniqueString(resourceGroup().id), 0,3)}') {
  name: '${appName}-f1'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {

      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
        	name: 'target_folder'
        	value: 'processed'
        }
        {
        	name: 'sas_url'
        	value: container_sas_url
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'wpbconnstr_STORAGE'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.9'
    }
    httpsOnly: true
  }
}

var sdgsimilarity_unique = uniqueString(resourceGroup().id)
var sdgsimilarity_suffix = substring(sdgsimilarity_unique, 0, 2)


resource functionAppSDGSimilarity 'Microsoft.Web/sites@2021-03-01' = if (appName == '${global_prefix}-sdgsimilarity-${substring(uniqueString(resourceGroup().id), 0,3)}') {
  name: '${appName}-f2'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {

      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.9'
    }
    httpsOnly: true
  }
}
param search_api_key string
param search_api_version string
param search_index string
param video_indexer_account_id string
param video_indexer_api_key string
param video_indexer_endpoint string
param video_indexer_location string
param video_indexer_location_url_prefix string
param video_indexer_resource_id string

resource functionAppVideoIndexer 'Microsoft.Web/sites@2021-03-01' = if (appName == '${global_prefix}-videoindexer-${substring(uniqueString(resourceGroup().id), 0,3)}') {
  name: '${appName}-f4'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {

      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'blob_account'
          value: '${storageAccountName}'
        }
        {
          name: 'blob_container'
          value:'${videoContainerName}'
        }
        {
          name: 'blob_container_source'
          value: '${videoContainerSource}'
        }
        {
          name: 'blob_key'
          value: '${blobAccountKey}'
        }
        {
          name: 'entities'
          value: 'transcript,ocr,keywords,topics,faces,labels,brands,namedLocations,namedPeople'
        }
        {
          name: 'search_account'
          value: '${search_name}'
        }
        {
          name: 'search_api_key'
          value: '${search_api_key}'
        }
        {
          name: 'search_api_version'
          value: '${search_api_version}'
        }
        {
          name: 'search_index'
          value: '${search_index}'
        }
        {
          name: 'video_indexer_account_id'
          value: '${video_indexer_account_id}'
        }
        {
          name: 'video_indexer_api_key'
          value: '${video_indexer_api_key}'
        }
        {
          name: 'video_indexer_endpoint'
          value: '${video_indexer_endpoint}'
        }
        {
          name: 'video_indexer_location'
          value: '${video_indexer_location}'
        }
        {
          name: 'video_indexer_location_url_prefix'
          value: '${video_indexer_location_url_prefix}'
        }
        {
          name: 'video_indexer_resource_id'
          value: '${video_indexer_resource_id}'
        }
        {
          name: 'videoknowledgemining_STORAGE'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }

      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.9'
    }
    httpsOnly: true
  }
}


resource functionAppVideoCallback 'Microsoft.Web/sites@2021-03-01' = if (appName == '${global_prefix}-videocallback-${substring(uniqueString(resourceGroup().id), 0,3)}') {
  name: '${appName}-f5'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {

      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'blob_account'
          value: '${storageAccountName}'
        }
        {
          name: 'blob_container'
          value:'${videoContainerName}'
        }
        {
          name: 'blob_container_source'
          value: '${videoContainerSource}'
        }
        {
          name: 'blob_key'
          value: '${blobAccountKey}'
        }
        {
          name: 'entities'
          value: 'transcript,ocr,keywords,topics,faces,labels,brands,namedLocations,namedPeople'
        }
        {
          name: 'search_account'
          value: '${search_name}'
        }
        {
          name: 'search_api_key'
          value: '${search_api_key}'
        }
        {
          name: 'search_api_version'
          value: '${search_api_version}'
        }
        {
          name: 'search_index'
          value: '${search_index}'
        }
        {
          name: 'video_indexer_account_id'
          value: '${video_indexer_account_id}'
        }
        {
          name: 'video_indexer_api_key'
          value: '${video_indexer_api_key}'
        }
        {
          name: 'video_indexer_endpoint'
          value: '${video_indexer_endpoint}'
        }
        {
          name: 'video_indexer_location'
          value: '${video_indexer_location}'
        }
        {
          name: 'video_indexer_location_url_prefix'
          value: '${video_indexer_location_url_prefix}'
        }
        {
          name: 'video_indexer_resource_id'
          value: '${video_indexer_resource_id}'
        }
        {
          name: 'videoknowledgemining_STORAGE'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }

      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.9'
    }
    httpsOnly: true
  }
}


var openai_unique = uniqueString(resourceGroup().id)
var openai_suffix = substring(openai_unique, 0, 2)

resource functionAppOpenAI 'Microsoft.Web/sites@2021-03-01' = if (appName == '${global_prefix}-openai-${substring(uniqueString(resourceGroup().id), 0,3)}') {
  name: '${appName}-f3'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {

      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(appName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
        	name: 'openaiapikey'
        	value: openai_api_key
        }
        {
          name: 'openaiapitype'
          value: openai_api_type
        }
        {
          name: 'openaiapibase'
          value: openai_api_base
        }
        {
          name: 'openaiapiversion'
          value: openai_api_version
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      linuxFxVersion: 'Python|3.9'
    }
    httpsOnly: true
  }
}



resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}