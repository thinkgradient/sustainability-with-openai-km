import logging
import io, os
import azure.functions as func
import PyPDF2
from azure.storage.blob import ContainerClient
from azure.storage.blob import ContentSettings



def main(myblob: func.InputStream):
    logging.info(f"Python blob trigger function processed blob \n"
                 f"Name: {myblob.name}\n"
                 f"Blob Size: {myblob.length} bytes")
    target_folder = os.environ['target_folder']
    connection_str = os.environ['connection_str']
    container_name = os.environ['container_name']
    name_without_ext = myblob.name.split("/")[1].split(".")[0]
    
    blob_bytes = myblob.read()
    blob_to_read = io.BytesIO(blob_bytes)
    inputpdf = PyPDF2.PdfReader(blob_to_read)
    
    individual_files = []
    stream = io.StringIO()
    

    container_client = ContainerClient.from_connection_string(connection_str, container_name=container_name)

    for i in range(len(inputpdf.pages)):
        output = PyPDF2.PdfWriter()
        output.add_page(inputpdf.pages[i])
        individual_files.append(output)
        if name_without_ext != "processed":
            with open("/tmp/" + name_without_ext + "-page%s.pdf" % (i + 1), "wb") as outputStream:
                output.write(outputStream)
        
            with open(outputStream.name, 'rb') as f:
                data = f.seek(0)
                data = f.read()
                target_blob = outputStream.name.replace("/tmp/",target_folder + "/")
                blob_client = container_client.get_blob_client(blob = target_blob)
                blob_client.upload_blob(data, blob_type="BlockBlob", content_settings=ContentSettings( content_type='application/pdf')) 

            stream.truncate(0)
