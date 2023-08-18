import psycopg2
import boto3
import os
import json
import base64

dbname = os.environ["db"]
user = os.environ["user"]
secret_name = os.environ["secret"]
host = os.environ["host"]
port = int(os.environ["port"])

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

def get_rds_password():
    client = boto3.client(
        service_name='secretsmanager',
        region_name='eu-west-1'
    )
    get_secret_value_response = client.get_secret_value(
        SecretId=secret_name
    )

    if 'SecretString' in get_secret_value_response:
        secret = get_secret_value_response['SecretString']
        j = json.loads(secret)
        password = j['password']
    else:
        decoded_binary_secret = base64.b64decode(get_secret_value_response['SecretBinary'])
        print("password binary:" + decoded_binary_secret)
        password = decoded_binary_secret.password   

    print("password:", password)

    return password 

def lambda_handler(event, context):
    print("started lambda")
    password = get_rds_password()
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
