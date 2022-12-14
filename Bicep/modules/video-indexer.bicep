@description('Service name must only contain lowercase letters, digits or dashes, cannot use dash as the first two or last one characters, cannot contain consecutive dashes, and is limited between 2 and 60 characters in length.')

/*
  Deploy Media Service 
*/

param location string
param global_prefix string
param storageAccountId string
param videoAccountName string
param userAssignedMangedIdentityName string 


/*
  Create User Assigned Identity  
*/

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: userAssignedMangedIdentityName
  location: location

}

/*
  Create Media Service with above User Assigned Identity  
*/

var mediaServiceName = '${global_prefix}m${videoAccountName}${substring(uniqueString(resourceGroup().id), 0,3)}'
var videoServiceName = '${global_prefix}v${videoAccountName}${substring(uniqueString(resourceGroup().id), 0,3)}'


resource mediaService 'Microsoft.Media/mediaservices@2021-06-01' = {
  name: mediaServiceName
  location: location
  
   properties: {
     storageAccounts: [
       {
         id: '${storageAccountId}'
         type: 'Primary'
       }
     ]
   }
   identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
      }
   }

  }


var roleDefinitionIdVideoIndexer = {
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

/*
  Assign Contributor role to User Assigned Identity service principal id
*/

resource assignContributorToMediaService 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, mediaService.name, 'AssignUserIdentitytoMediaService', '${substring(uniqueString(resourceGroup().id), 0,5)}')   
  scope: mediaService
  properties: {
    description: 'Assign Contributor role for User Assigned Identity to Media Services'
    principalId: '${userAssignedIdentity.properties.principalId}'
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionIdVideoIndexer['Contributor'].id
  }
}


/*
  Create Video Indexer with User Assigned Identity which has Contributor rights on Media Services
*/

var mediaServiceResId  = resourceId('Microsoft.Media/mediaservices', mediaServiceName)

resource videoIndexerAccount 'Microsoft.VideoIndexer/accounts@2022-08-01' = {
  name: videoServiceName
  location: location
  dependsOn: [
    assignContributorToMediaService
  ]
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities : {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    mediaServices: {
      resourceId: mediaServiceResId
      userAssignedIdentity: '${userAssignedIdentity.id}'
    }
  }
}

var videoServiceResId  = resourceId('Microsoft.VideoIndexer/accounts', videoServiceName)

// outputs

// video_indexer_account_id: '${video_indexer_account_id}'

output videoIndexAccountId string = '${videoIndexerAccount.properties.accountId}'
output videoIndexerResourceId string =  '${videoServiceResId}'

// video_indexer_api_key: '${video_indexer_api_key}'


