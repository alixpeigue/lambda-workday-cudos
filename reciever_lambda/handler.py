import json
import os
from re import S
from typing import Any

import psycopg2
import psycopg2.extras

from pydantic import BaseModel

dbname = os.environ["dbname"]
host = os.environ["host"]
port = int(os.environ["port"])
region = os.environ["region"]

# Models definition

class Project(BaseModel):
    id: str
    name: str
    owner: str
    company: str | None
    community: str

class Credentials(BaseModel):
    username: str
    password: str

class Message(BaseModel):
    credentials: Credentials
    data: list[Project]


def create_table_if_not_exists(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS workday (
                id VARCHAR(10) PRIMARY KEY,
                name TEXT NOT NULL,
                owner TEXT NOT NULL,
                company TEXT,
                community TEXT NOT NULL
            )
            """)
        conn.commit()

def update_or_insert_tuples(conn, data: list[tuple[str, str, str, str|None, str]]):
    with conn.cursor() as cur:
        insert_query = """
            INSERT INTO workday (id, name, owner, company, community)
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
    message_dict = json.loads(event['Records'][0]['body'])
    message = Message(**message_dict)
    print("Message parsed : ", message)
    credentials = message.credentials
    password, user = credentials.password, credentials.username
    conn = psycopg2.connect(dbname=dbname, user=user, password=password, host=host, port=port)
    print("connected")

    create_table_if_not_exists(conn)
    print("table created")

    update_or_insert_tuples(conn, [(el.id, el.name, el.owner, el.company, el.community) for el in message.data])
    print("values inserted")

    table = get_table_contents(conn)
    print("table : ", table)

    conn.close()
    print("Done")
