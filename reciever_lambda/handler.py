import json
import os
from typing import Any

import psycopg2
import psycopg2.extras

dbname = os.environ["dbname"]
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

def update_or_insert_tuples(conn, data: list[tuple[str, str]]):
    with conn.cursor() as cur:
        insert_query = """
            INSERT INTO workday (id, name)
            VALUES %s
            ON CONFLICT (id) DO UPDATE 
                SET name = EXCLUDED.name
        """
        psycopg2.extras.execute_values(cur, insert_query, data)
        conn.commit()

def get_table_contents(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM workday")
        return cur.fetchall()

def lambda_handler(event, context):
    message: dict[str, Any] = json.loads(event['Records'][0]['body'])
    print("Message parsed : ", message)
    credentials = message["secret"]
    password, user = credentials["password"], credentials["username"]
    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    print("connected")

    create_table_if_not_exists(conn)
    print("table created")

    update_or_insert_tuples(conn, [(el['id'], el['name']) for el in message["data"]])
    print("values inserted")

    table = get_table_contents(conn)
    print("table : ", table)

    conn.close()
    print("Done")
