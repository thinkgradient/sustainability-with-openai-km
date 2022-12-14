@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param global_prefix string
param serviceName string
param cognitiveServiceName string = '${global_prefix}-${serviceName}-${substring(uniqueString(resourceGroup().id), 0,3)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'S0'
])

param sku string = 'S0'

resource cognitiveService 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: cognitiveServiceName
  location: location
  sku: {
    name: sku
  }
  kind: 'CognitiveServices'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
  }
}