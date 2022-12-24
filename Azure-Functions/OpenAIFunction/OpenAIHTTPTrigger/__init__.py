import logging
import json
import azure.functions as func
import openai
from time import time,sleep
import textwrap
import re
import os

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')
    try:
        body = json.dumps(req.get_json())
        
    except ValueError:
        return func.HttpResponse(
             "Invalid body",
             status_code=400
        )
    
    if body:
        
        result = compose_response(body)
        return func.HttpResponse(result, mimetype="application/json")
    else:
        return func.HttpResponse(
             "Invalid body",
             status_code=400
        )


def compose_response(json_data):
    values = json.loads(json_data)['values']
    
    # Prepare the Output before the loop
    results = {}
    results["values"] = []
    
    for value in values:
        output_record = transform_value(value)
        if output_record != None:
            results["values"].append(output_record)
    logging.info(results)
    return json.dumps(results, ensure_ascii=False)


def transform_value(value):


    openai.api_key = os.environ['openaiapikey'] #
    openai.api_type = os.environ['openaiapitype'] # 
    openai.api_base = os.environ['openaiapibase'] # 
    openai.api_version = os.environ['openaiapiversion'] #

    try:         
        assert ('data' in value), "'data' field is required."
        data = value['data']        
        assert ('text' in data), "'text' field is required in 'data' object."
        
    except AssertionError  as error:
        return (
            {
             "recordId": value['recordId'],
            "errors": [ { "message": "Error:" + error.args[0] }   ]       
            })

    try:
        
        chunks = textwrap.wrap(value['data']['text'], 2000)
        results = None
        for chunk in chunks:
            prompt = chunk.encode(encoding='ASCII',errors='ignore').decode()
            results = gpt3_completion(prompt)
            break
        
        category = results['category']
        summary = results["summary"]
        if "category of" in category:
            category = re.sub(r'[^\w\s]', '', category.split("category of")[1].strip())
        
    except:
        return (
            {
             "recordId": value['recordId'],
            "errors": [ { "message": "Could not complete operation for record." }   ]       
            })

    return ({
        
            "recordId": value['recordId'],
            # "language":"en",
            "data": {
                "category": category,
                "summary": summary
                    }
            })


def gpt3_completion(prompt, engine='davinci-002', temp=0.6, top_p=1.0, tokens=2000, freq_pen=0.25, pres_pen=0.0):
    max_retry = 5

    retry = 0

    sleep(1)
    results = {}
    while True:
        
        try:
            sleep(1) # to avoid rate limits
            prompt_text = "Write a concise summary of the following:\n\n-------\n\n" + prompt + "\n\n-------"
            response_summary = openai.Completion.create(
                engine=engine,
                prompt= prompt_text,
                temperature=temp,
                max_tokens=tokens,
                top_p=top_p,
                frequency_penalty=freq_pen,
                presence_penalty=pres_pen)
            text_summary = response_summary['choices'][0]['text'].strip()
            text_summary = re.sub('\s+', ' ', text_summary)
            results['summary'] = text_summary
            sleep(1) # to avoid rate limits
            
            response_category = openai.Completion.create(
                engine=engine,
                prompt="What category:\n\n-------\n\n" + text_summary + "\n\n-------",
                temperature=0,
                max_tokens=tokens,
                top_p=1.0,
                frequency_penalty=0.25,
                presence_penalty=0.0
            )
            text_category = response_category['choices'][0]['text'].strip()
            text_category = re.sub('\s+', ' ', text_category)
            # please_word = (text_category.replace(".","").strip().split(" ")[0] == "Please")
            # seconds_word = (text_category.replace(".","").strip().split(" ")[4] == "seconds")
            # if please_word and seconds_word:
            #     text_category = "OpenAI Service Limitation"
            results['category'] = text_category
            
            return results
        except Exception as oops:
            retry += 1
            if retry >= max_retry:
                return "GPT3 error: %s" % oops
            print('Error communicating with OpenAI:', oops)
            sleep(1)
