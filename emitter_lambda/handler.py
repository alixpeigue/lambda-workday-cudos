import json
import os
from typing import Any, TypeAlias

import boto3
import requests
from botocore.exceptions import ClientError

sqs_url = os.environ["sqs"]
secret = os.environ["secret"]
region = os.environ["region"]

session = boto3.session.Session()

def get_credentials(secret: str, region: str) -> dict[str, str]:

    client = session.client(
        service_name='secretsmanager',
        region_name=region
    )
    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret
        )
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e
    
    # Decrypts secret using the associated KMS key.
    return json.loads(get_secret_value_response['SecretString'])

def get_data() -> list[dict[str, str]]:
    req = requests.get("https://dummyjson.com/products")
    response = req.json()
    print(response)
    return [{"id": el["id"], "name": el["title"]} for el in response["products"][:10]]

def send_message(sqs_url: str, message: dict[str, Any]) -> None :
    print(message)
    sqs = session.client('sqs')
    sqs.send_message(
        QueueUrl = sqs_url,
        MessageBody = json.dumps(message)
    )

def lambda_handler(event, context):
    print("starting")
    credentials = get_credentials(secret, region)
    print("got credentials")
    data = get_data()
    print("got data")
    send_message(sqs_url, {
        "data": data,
        "secret": credentials
    })