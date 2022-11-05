import logging
import json 
import azure.functions as func
from gensim.models import Word2Vec
from gensim.models.phrases import Phraser, Phrases
from gensim.models.doc2vec import Doc2Vec, TaggedDocument
from nltk.tokenize import word_tokenize
import smart_open
import gensim
import nltk
import string
from nltk.corpus import stopwords
nltk.download('stopwords')
nltk.download('punkt')
stopwords_en = stopwords.words("english")


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


def preprocess(text):
    worldlist = nltk.word_tokenize(text)
    tokenized = [word.translate(str.maketrans('','',string.punctuation)) for word in worldlist]
    tokenized = [w.lower() for w in tokenized if w not in stopwords_en and not w.isdigit()]
    tokenized = list(filter(None,tokenized))
    return tokenized

def read_corpus(fname, tokens_only=False):
    with smart_open.open(fname, encoding="iso-8859-1") as f:
        for i, line in enumerate(f):
            tokens = gensim.utils.simple_preprocess(line)
            if tokens_only:
                yield tokens
            else:
                # For training data, add tags
                yield gensim.models.doc2vec.TaggedDocument(tokens, [i])


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
        
        pdf_text = value['data']['text']
         
        goals_file = "goals.txt"
        train_corpus = list(read_corpus(goals_file))
        test_corpus = list(read_corpus(goals_file, tokens_only=True))
        model = gensim.models.doc2vec.Doc2Vec(vector_size=50, min_count=2, epochs=40)
        model.build_vocab(train_corpus)
        model.train(train_corpus, total_examples=model.corpus_count, epochs=model.epochs)
        tokens = gensim.utils.simple_preprocess(pdf_text)
        inferred_vector = model.infer_vector(tokens)
        sdg_mapping = {
            0: 'No Poverty',
            1: 'Zero Hunger',
            2: 'Good Health and Well-Being',
            3: 'Quality Education',
            4: 'Gender Equality',
            5: 'Clean Water and Sanitation',
            6: 'Affordable and Clean Energy',
            7: 'Decent Work and Economic Growth',
            8: 'Industry, Innovation and Infrastructure',
            9: 'Reduced Inequalities',
            10: 'Sustainable Cities and Communities',
            11: 'Responsible Consumption and Production',
            12: 'Climate Action',
            13: 'Life Below Water',
            14: 'Life on Land',
            15: 'Peace, Justics and Strong Institutions',
            16: 'Partnerships for the Goals'
        }
        sims = model.dv.most_similar([inferred_vector], topn=len(model.dv))
        sdg = "No SDG"
        if sims[0][1] > 0.5:
            sdg = sdg_mapping[sims[0][0]]

        
        
        
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
                "UN_SDG": sdg
                    }
            })
    
