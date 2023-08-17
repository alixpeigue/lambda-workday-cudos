import boto3
import requests
import json
import os

sqs_url = os.environ["sqs"]

def lambda_handler(event, context):
    sqs = boto3.client('sqs')
    print("client created")
    message = {
        "id": "erddsd",
        "name": "project",
    }
    sqs.send_message(
        QueueUrl = sqs_url,
        MessageBody = json.dumps(message)
    )
    print("message sent")