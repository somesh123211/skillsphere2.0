import os
import pymysql
from dbutils.pooled_db import PooledDB

# ------------------------------------------------------------------
# IMPORTANT:
# - Environment variables MUST be loaded BEFORE this file is imported
# - app.py must call load_dotenv() at the very top
# ------------------------------------------------------------------

# Optional debug (comment out after first successful run)


# ------------------------------------------------------------------
# DB CONNECTION POOL
# ------------------------------------------------------------------
pool = PooledDB(
    creator=pymysql,
    maxconnections=30,      # Max total connections for 30 generation threads
    mincached=1,            # Do NOT pre-create connections (safe startup)
    maxcached=2,            # Max idle connections
    blocking=True,          # Wait if pool is exhausted
    ping=1,                 # Check (and silently reconnect) a cursored
                             # connection before use - without this, an idle
                             # pooled connection that MySQL has since dropped
                             # (wait_timeout, network blip) raises "MySQL
                             # server has gone away" / InterfaceError(0, '')
                             # on the next request that happens to reuse it.
    host=os.getenv("MYSQL_HOST"),
    user=os.getenv("MYSQL_USER"),
    password=os.getenv("MYSQL_PASSWORD"),
    database=os.getenv("MYSQL_DB"),
    cursorclass=pymysql.cursors.DictCursor,
    autocommit=True
)

import time

def get_db():
    """
    Returns a pooled database connection with automatic 5-attempt retry loop.
    Calling .close() will RETURN the connection to the pool.
    """
    last_err = None
    for attempt in range(5):
        try:
            return pool.connection()
        except Exception as e:
            last_err = e
            time.sleep(0.15)
    raise last_err
