import os
import csv
import socket
import mysql.connector
from datetime import datetime
import configparser
import logging

# Configure logging to track synchronization process
logging.basicConfig(
    filename='/home/ubuntu/CDN/log/database.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Read database configuration from mysql.ini
config = configparser.ConfigParser()
config.read('/home/ubuntu/CDN/mysql.ini')

# Local database configuration
DB_CONFIG_LOCAL = {
    'host': config['mysql']['host'],
    'user': config['mysql']['user'],
    'password': config['mysql']['password'],
    'database': config['mysql']['database'],
    'ssl_disabled': config['mysql']['ssl_disabled'],
}

# Backup database configuration
DB_CONFIG_BACKUP = {
    'host': config['backup']['host'],
    'user': config['backup']['user'],
    'password': config['backup']['password'],
    'database': config['backup']['database'],
    'ssl_disabled': config['backup']['ssl_disabled'],
}

FILE_PATH = '/home/ubuntu/CDN/data/data.csv'
HOSTNAME = socket.gethostname()
xfactor = 2

def get_last_sync_time(cursor, hostname=None):
    """Retrieve the most recent synchronization time from the database."""
    try:
        if hostname:
            query = "SELECT MAX(time) FROM data WHERE server = %s"
            cursor.execute(query, (hostname,))
        else:
            query = "SELECT MAX(time) FROM data"
            cursor.execute(query)
        result = cursor.fetchone()[0]
        return result if result else datetime.strptime('1970-01-01 00:00:00', "%Y-%m-%d %H:%M:%S")
    except Exception as e:
        logging.error(f"Error retrieving last sync time: {e}")
        raise


def insert_data(cursor, time, app, stream, requests, unique_users, data_sent, server):
    """Insert data into the database, ignoring duplicates."""
    try:
        query = """
        INSERT IGNORE INTO data (time, server, app, stream, requests, unique_users, data_sent)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (time, server, app, stream, requests, unique_users, data_sent))
    except Exception as e:
        logging.error(f"Error inserting data into the database: {e}")
        raise


def sync_to_local(file_path, db_config):
    """Synchronize data to the local database."""
    conn_local = None
    try:
        conn_local = mysql.connector.connect(**db_config)
        cursor_local = conn_local.cursor()

        last_sync_time_local = get_last_sync_time(cursor_local)

        rows_synced = 0
        with open(file_path, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                time = datetime.strptime(row['Time'], "%d/%m/%Y %H:%M")
                app = row['App']
                stream = row['Stream']
                requests = int(row['Requests'])
                unique_users = int(row['Unique Users'])
                data_sent = int(row['Data Sent (bytes)']) * xfactor

                if time >= last_sync_time_local:
                    insert_data(cursor_local, time, app, stream, requests, unique_users, data_sent, HOSTNAME)
                    rows_synced += 1

        conn_local.commit()
        logging.info(f"Successfully synchronized {rows_synced} rows to local database.")
    except Exception as e:
        logging.error(f"Error during local synchronization: {e}")
    finally:
        if conn_local and conn_local.is_connected():
            conn_local.close()


def sync_to_backup(file_path, db_config, hostname):
    """Synchronize data to the backup database."""
    conn_backup = None
    try:
        conn_backup = mysql.connector.connect(**db_config)
        cursor_backup = conn_backup.cursor()

        last_sync_time_backup = get_last_sync_time(cursor_backup, hostname)

        rows_synced = 0
        with open(file_path, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                time = datetime.strptime(row['Time'], "%d/%m/%Y %H:%M")
                app = row['App']
                stream = row['Stream']
                requests = int(row['Requests'])
                unique_users = int(row['Unique Users'])
                data_sent = int(row['Data Sent (bytes)']) * xfactor

                if time >= last_sync_time_backup:
                    insert_data(cursor_backup, time, app, stream, requests, unique_users, data_sent, hostname)
                    rows_synced += 1

        conn_backup.commit()
        logging.info(f"Successfully synchronized {rows_synced} rows to backup database.")
    except Exception as e:
        logging.error(f"Error during backup synchronization: {e}")
    finally:
        if conn_backup and conn_backup.is_connected():
            conn_backup.close()


if __name__ == "__main__":
    if not os.path.exists(FILE_PATH):
        logging.warning("File data.csv not found. Exiting.")
    else:
        sync_to_local(FILE_PATH, DB_CONFIG_LOCAL)
        sync_to_backup(FILE_PATH, DB_CONFIG_BACKUP, HOSTNAME)
