import os
import logging
import boto3
from flask import Flask, request, render_template_string

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

AWS_REGION = os.environ["AWS_REGION"]
QUEUE_URL = os.environ["QUEUE_URL"]
sqs_client = boto3.client("sqs", region_name=AWS_REGION)

# Simple HTML form
SQS_FORM = """
<!DOCTYPE html>
<html>
  <body>
    <h1>Send a Message to SQS</h1>
    <form method="POST" action="/send">
      <label>Message:</label>
      <input type="text" name="message" required/>
      <br/><br/>
      <button type="submit">Send to SQS</button>
    </form>
  </body>
</html>
"""

@app.route("/send", methods=["GET", "POST"])
def send():
    if request.method == "GET":
        return render_template_string(SQS_FORM)

    message = request.form.get("message")
    if not message:
        logger.warning("No message provided.")
        return "No message provided.", 400

    try:
        response = sqs_client.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=message
        )
        message_id = response.get("MessageId", "N/A")
        logger.info("Message '%s' sent to '%s' (MessageId: %s).", message, QUEUE_URL, message_id)
        return f"Message sent to SQS! (MessageId: {message_id})"
    except Exception as exc:
        logger.exception("Error sending message to SQS.")
        return f"Error sending message to SQS: {str(exc)}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)