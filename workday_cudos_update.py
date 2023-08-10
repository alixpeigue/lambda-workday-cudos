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

def lambda_handler(event, context):
    print(1)
    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    print(2)
    with conn.cursor() as cur:
        print(3)
        cur.execute("""
                    CREATE TABLE IF NOT EXISTS workday (
                        id VARCHAR(10) PRIMARY KEY,
                        name TEXT
                    )""")
        print(4)
        conn.commit()
    print(5)
    conn.close()
    print("Done")

# lambda_handler(None, None)

