import boto3
import psycopg2
import requests
import os
import json

dbname = os.environ["db"]
user = os.environ["user"]
password = os.environ["password"]
host = os.environ["host"]
port = int(os.environ["port"])

# dbname = "postgres"
# user = "postgres"
# password = "password"
# host = "127.0.0.1"
# port = 5432

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

def lambda_handler(event, context):
    print("started lambda")
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

# lambda_handler(None, None)
