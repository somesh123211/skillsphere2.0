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
    maxconnections=8,       # Strictly capped at 8 (MySQL host max_user_connections = 10)
    mincached=1,            # Safe startup connection
    maxcached=4,            # Reuse up to 4 idle connections
    blocking=True,          # Safely wait in memory if pool is temporarily full
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
