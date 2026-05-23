import os
import logging
import boto3
from flask import Flask, request, render_template_string
from werkzeug.utils import secure_filename

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

AWS_REGION = os.environ["AWS_REGION"]
BUCKET_NAME = os.environ["BUCKET_NAME"]
s3_client = boto3.client("s3", region_name=AWS_REGION)

# Simple HTML form for file upload
UPLOAD_FORM = """
<!DOCTYPE html>
<html>
  <body>
    <h1>Upload a File to S3</h1>
    <form method="POST" action="/upload" enctype="multipart/form-data">
      <label>Select file:</label>
      <input type="file" name="file" required/>
      <br/><br/>
      <button type="submit">Upload</button>
    </form>
  </body>
</html>
"""

@app.route("/upload", methods=["GET", "POST"])
def upload_file():
    if request.method == "GET":
        return render_template_string(UPLOAD_FORM)

    file_obj = request.files.get("file")
    if not file_obj or file_obj.filename.strip() == "":
        logger.warning("No valid file provided.")
        return "No valid file provided.", 400

    filename = secure_filename(file_obj.filename)

    try:
        s3_client.upload_fileobj(file_obj, BUCKET_NAME, filename)
        logger.info("File '%s' uploaded to bucket '%s'.", filename, BUCKET_NAME)
        return f"File '{filename}' uploaded successfully to S3 bucket '{BUCKET_NAME}'!"
    except Exception as exc:
        logger.exception("Error uploading file to S3.")
        return f"Error uploading file: {str(exc)}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)

