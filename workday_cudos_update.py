import boto3
import psycopg2
import requests
import os

dbname = os.environ("db")
user = os.environ("user")
password = os.environ("password")
host = os.environ("host")
port = os.environ("port")

def lambda_handler(event, context):
    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    with conn.cursor() as cur:
        cur.execute("""
                    CREATE TABLE IF NOT EXISTS workday (
                        id VARCHAR(10) PRIMARY KEY
                        name TEXT
                    )""")
        conn.commit()
    conn.close()

