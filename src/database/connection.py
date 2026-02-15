import mysql.connector
from mysql.connector import pooling
import os

DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "Kiaradiallo2020",
    "database": "classicmodels"
}   

os.chdir("C:/Users/ibrah/OneDrive/Documents/classicmodel-analysis")
#import db_config

connection_pool = pooling.MySQLConnectionPool(
    pool_name="classicmodels_pool",
    pool_size=5,
    **DB_CONFIG
)

def get_connection():
    return connection_pool.get_connection()
