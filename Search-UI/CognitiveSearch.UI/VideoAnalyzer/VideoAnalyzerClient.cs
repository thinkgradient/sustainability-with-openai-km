// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using Azure.Core;
using Azure.Identity;

using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using System;
using System.Linq;
using System.Net.Http;
using System.Security.Authentication;
using System.Text;
using System.Threading.Tasks;

namespace CognitiveSearch.UI
{
    public class VideoAnalyzerAccessToken
    {
        public string AccessToken { get; set; }

    }
    public class VideoAnalyzerClient
    {
        private IConfiguration _configuration { get; set; }

        private string apiUrl { get; set; }
        private string apiKey { get; set; }
        private string accountId { get; set; }
        private string accountLocation { get; set; }
        private string resourceId { get; set; }

        public VideoAnalyzerClient(IConfiguration configuration)
        {
            try
            {
                _configuration = configuration;

                apiUrl = "https://api.videoindexer.ai";
                apiKey = _configuration.GetSection("AVAM_Api_Key")?.Value;
                accountId = _configuration.GetSection("AVAM_Account_Id")?.Value;
                accountLocation = _configuration.GetSection("AVAM_Account_Location")?.Value;
                resourceId = _configuration.GetSection("AVAM_Resource_Id")?.Value;

            }
            catch (Exception e)
            {
                // If you get an exception here, most likely you have not set your
                // credentials correctly in appsettings.json
                throw new ArgumentException(e.Message.ToString());
            }
        }


        public async Task<string> GetAccessToken(string videoId)
        {
            // TLS 1.2 (or above) is required to send requests
            var httpHandler = new SocketsHttpHandler();
            httpHandler.SslOptions.EnabledSslProtocols |= SslProtocols.Tls12;
            var client = new HttpClient(httpHandler);

            if (apiKey == null || apiKey == "")
            {
                // Use AzureCredential to generate Azure Video Analyzer for Media Access Token
                var credential = new ChainedTokenCredential(new ManagedIdentityCredential(), new DefaultAzureCredential());

                string[] scopes = new string[1];
                scopes[0] = "https://management.azure.com/.default";
                var access_token = credential.GetToken(new TokenRequestContext(scopes));
                Console.WriteLine(access_token.Token.ToString());
                string url = $"https://management.azure.com{resourceId}/generateAccessToken?api-version=2021-10-18-preview";

                var getAccountsRequest = new HttpRequestMessage(HttpMethod.Post, url);
                getAccountsRequest.Headers.Add("Authorization", $"Bearer {access_token.Token.ToString()}");
                getAccountsRequest.Content = new StringContent("{\"permissionType\":\"Contributor\",\"scope\": \"Account\"}", Encoding.UTF8, "application/json");
                var result = await client.SendAsync(getAccountsRequest);
                string accessToken = await result.Content.ReadAsStringAsync();
                var accessTokenObj = JsonConvert.DeserializeObject<VideoAnalyzerAccessToken>(accessToken);
                accessToken = $"https://www.videoindexer.ai/embed/player/{accountId}/{videoId}?location={accountLocation}&accessToken={accessTokenObj.AccessToken}";

                return accessToken;
            }

            else
            {
                // Use API Key for Video Indexer (or not ARM Azure Video Analyzer for Media)
                var getAccountsRequest = new HttpRequestMessage(HttpMethod.Get, $"{apiUrl}/auth/{accountLocation}/Accounts/{accountId}/Videos/{videoId}/AccessToken");
                getAccountsRequest.Headers.Add("Ocp-Apim-Subscription-Key", apiKey);
                getAccountsRequest.Headers.Add("x-ms-client-request-id", Guid.NewGuid().ToString()); // Log the request id so you can include it in case you wish to report an issue for API errors or unexpected API behavior
                var result = await client.SendAsync(getAccountsRequest);
                Console.WriteLine("Response id to log: " + result.Headers.GetValues("x-ms-request-id").FirstOrDefault()); // Log the response id so you can include it in case you wish to report an issue for API errors or unexpected API behavior
                string accessToken = (await result.Content.ReadAsStringAsync()).Trim('"'); // The access token is returned as JSON value surrounded by double-quotes

                accessToken = $"https://www.videoindexer.ai/embed/player/{accountId}/{videoId}?location={accountLocation}&accessToken={accessToken}";

                return accessToken;
            }
        }
    }
}
