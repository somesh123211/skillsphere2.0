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
    maxconnections=10,      # Strict cap matching site4now MySQL max_user_connections (10)
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

def get_db():
    """
    Returns a pooled database connection.
    Calling .close() will RETURN the connection to the pool.
    """
    return pool.connection()
