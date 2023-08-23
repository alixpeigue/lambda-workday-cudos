import os
import json
import base64

import psycopg2
import boto3

from botocore.exceptions import ClientError

dbname = os.environ["db"]
secret_name = os.environ["secret"]
host = os.environ["host"]
port = int(os.environ["port"])
region = os.environ["region"]

def create_table_if_not_exists(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS workday (
                id VARCHAR(10) PRIMARY KEY,
                name TEXT
            )
            """)
        conn.commit()

def update_or_insert_tuple(conn, data):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO workday (id, name)
            VALUES (%s, %s)
            ON CONFLICT (id) DO UPDATE 
                SET name = EXCLUDED.name
            """,
            (data['id'], data['name']))
        conn.commit()

def get_credentials():
    print("1")
    session = boto3.session.Session()
    print("2")
    client = session.client(
        service_name='secretsmanager',
        region_name=region
    )
    print("3")
    try:
        print("4")
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
        print("5")
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e
    print("6")
    # Decrypts secret using the associated KMS key.

    secret = json.loads(get_secret_value_response['SecretString'])

    password = secret['password']
    print("7")
    username = secret['username']
    print("8")
    return password, username

def lambda_handler(event, context):
    print("started lambda")
    # password, user = get_credentials()
    password = "Y+Ut_Jcyi45B6|Fp_)+PDW?gZgz9"
    user = "postgres"
    print("Recieved credentials : ", password, user)
    message = json.loads(event['Records'][0]['body'])
    print("Message parsed : ", message)

    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    print("connected")

    create_table_if_not_exists(conn)
    print("table created")

    update_or_insert_tuple(conn, message)
    print("values inserted")

    conn.close()
    print("Done")
