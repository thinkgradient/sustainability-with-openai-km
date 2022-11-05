"# sustainability-with-openai-km" 
Knowledge Mining Solution Accelerator - Code Samples | Microsoft Docs

	1. Resources have been deployed under HSBC RG:  wpbrg
	2. Git clone KM repo locally
	3. Index / Indexer and other Search components have been created using Postman (REST)
	

	5. Change \02 - Web UI Template\CognitiveSearch.UI\ file and replace with the given appsettings.json file 
	6. Replace the site.css file from \02 - Web UI Template\CognitiveSearch.UI\wwwroot\css with the given site.css file
	7. Replace the following two logos from \02 - Web UI Template\CognitiveSearch.UI\wwwroot\images with the provided logos:
		a. logo.png	
		b. Microsoft-logo_rgb_c-gray.png
	8. Web UI Template 
		a. Deploy using Docker version
		b. Replace .env file from \02 - Web UI Template\Docker with the provided .env file
		c. Execute command from : azure-search-knowledge-mining\02 - Web UI Template>
			i. To build image: docker build -f Docker\Dockerfile --tag wpb-km-web-ui .
			ii. To test and run image locally: docker run -p 8080:80 wpb-km-web-ui
	9. Create Container Registry in Azure Portal
	10. In command prompt run the following to push the docker image from your local docker server to the Container  Registry
		a. az login
		b. az acr login --name wpbregistry
		c. docker tag km-web-ui wpbregistry.azurecr.io/wpb-km-web-ui
		d. docker push wpbregistry.azurecr.io/wpb-km-web-ui
	11. Create web app from container image
		a. az webapp create --resource-group wpbrg --plan wpb-plan --name wpb-site-container --deployment-container-image-name wpbregistry.azurecr.io/wpb-km-web-ui:latest
	12. Configure website port number to 8000 for the app service as per instructions here: https://docs.microsoft.com/en-us/azure/app-service/tutorial-custom-container?pivots=container-linux#configure-app-service-to-deploy-the-image-from-the-registry
		a. az webapp config appsettings set --resource-group wpbrg --name fihsbc-site-container --settings WEBSITES_PORT=8000
	13. Assign system-assigned managed identity to the web app:
		a. az webapp identity assign --resource-group wpbrg --name wpb-site-container --query principalId --output tsv
			i. Result: AXXXXXXX-XXXXXXX-XXXXX-XXXXXXX
	14. Get subscription id:
		a. az account show --query id --output tsv
	15. Grant web app managed identity access to the container registry:
		a. az role assignment create --assignee  AXXXXXXX-XXXXXXX-XXXXX-XXXXXXX --scope /subscriptions/57fdad63-651c-4942-a0c1-83c7b430cf43/resourceGroups/wpbrg/providers/Microsoft.ContainerRegistry/registries/wpbregistry --role "AcrPull"
	16. Configure app to pull from Azure Container Registry
		a. az resource update --ids /subscriptions/57fdad63-651c-4942-a0c1-83c7b430cf43/resourceGroups/wpbrg/providers/Microsoft.Web/sites/wpb-site-container/config/web --set properties.acrUseManagedIdentityCreds=True
	17. az webapp log tail --name wpb-km-web-ui --resource-group wpbrg
	18. Enable automatic push to App Service from Container Registry
		a. Go to wpb-site-container App Service
		b. Click on Deployment Centre
		c. Make sure to enable Continuous Deployment 
		d. Copy the Webhook URL
		e. Then go to the container registry wpbregistry:
			i. Click on Webhooks
			ii. Click Add:
				1) Enter a name
				2) Enter location of your App Service
				3) In Service URI past the Webhook URL from 18d above.
				4) Set actions to D
				
			

There are three Azure Functions:
	1. PDFSplitter (Event triggered - storage blob - document/{name})
		a. Listen on designated storage container for any PDF files and splits each page into its own corresponding PDF file and store the results in a processed folder/namespace. Example if a PDF has 12 pages, the processed folder will contain 12 individual PDFs. This is done to circumvent the token limit that Open AI davinci model has during summarization (i.e. We cannot send the entire PDF document for summarization because of the 4096 token limit).
	2. OpenAIHTTPTrigger (HTTP triggered)
		a. Text input Azure Search skillset execution (merged_text is sent to this function) which takes the given input text and makes two API calls against OpenAI:
			i. Summarize text from the merged_text field (single PDF page)
			ii. Cateogorize summary and return result to Azure Search (index field: category)
	3. SDGSimilarity (HTTP triggered)
		a. Text input from Azure Search skillset execution (merged_text is sent to this function) which takes the given input text and compares the Doc2Vec similarity of the merged_text with the description of 17 UN SDGs provided in the goals.txt file. The name of the SDG with the highest similarity score is returned back and stored in an index field: UN_SDGs
	


Random Docker commands:
	1. docker container ls -a (list all containers)
	2. docker images (list docker images)
	3. docker container rm admiring_edison (remove container)
