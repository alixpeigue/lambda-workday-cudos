import boto3
import psycopg2
import requests
import os

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
                    )""")
        conn.commit()

def query_api():
    req = requests.get("https://jsonplaceholder.typicode.com/posts")
    print(req.json())

def lambda_handler(event, context):
    print("connecting...")
    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    print("connected")

    create_table_if_not_exists(conn)
    print("table created")

    query_api()

    conn.close()
    print("Done")

# lambda_handler(None, None)
