@description('The name of the app service that you wish to create.')
param appName string 
param global_prefix string
param acrName string 



@description('Location for all resources.')
param location string = resourceGroup().location

param storageName string

var webappName = '${appName}'
var hostingPlanName = '${appName}'
var applicationInsightsName = '${appName}'
var storageAccountName = '${global_prefix}${storageName}${substring(uniqueString(resourceGroup().id), 0,3)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName 
  location: resourceGroup().location
  sku: {
    name: 'B1'
    capacity: 1
  }
  kind: 'linux'
  properties: {
  	reserved: true
  }
}


resource app 'Microsoft.Web/sites@2020-06-01' = {
  name: webappName
  location: resourceGroup().location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      minTlsVersion: '1.2'
      linuxFxVersion: 'DOCKER|nginx'
      acrUseManagedIdentityCreds: true
      appSettings: [
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: listCredentials(resourceId('Microsoft.ContainerRegistry/registries', acrName), '2020-11-01-preview').passwords[0].value
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: '${acrName}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: '${acrName}'
        }
      ]
    }
  }
}

output appServiceManagedIdentity string = app.identity.principalId
output appserviceAppName string = webappName