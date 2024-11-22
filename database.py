import pandas as pd
from datetime import datetime
import mysql.connector
import time
import os
import configparser

def connect_db():
    config = configparser.ConfigParser()
    config.read('mysql.ini')

    if 'mysql' not in config:
        raise ValueError("Missing 'mysql' section in mysql.ini")

    host = config['mysql']['host']
    user = config['mysql']['user']
    password = config['mysql']['password']
    database = config['mysql']['database']
    ssl_disabled = config['mysql']['ssl_disabled']

    return mysql.connector.connect(
        host=host,
        user=user,
        password=password,
        database=database,
        ssl_disabled=ssl_disabled
    )

def load_data_to_db(filename, start_line):
    db_connection = connect_db()
    cursor = db_connection.cursor()

    df = pd.read_csv(filename, skiprows=range(1, start_line + 1))  
    df['Time'] = pd.to_datetime(df['Time'], format='%m/%d/%Y %H:%M')


    factor = 2  

    for _, row in df.iterrows():
        data_sent_adjusted = round(row['Data Sent (bytes)'] * factor)
        
        timestamp_str = row['Time'].strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute("""
            INSERT INTO data (time, app, stream, requests, unique_users, data_sent)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE 
                requests=VALUES(requests), unique_users=VALUES(unique_users), data_sent=VALUES(data_sent)
        """, (timestamp_str, row['App'], row['Stream'], row['Requests'], row['Unique Users'], data_sent_adjusted))

    db_connection.commit()
    cursor.close()
    db_connection.close()

    return start_line + len(df)  

def monitor_file(filename):
    if os.path.exists(filename):
        last_read_line = sum(1 for _ in pd.read_csv(filename, chunksize=1))
        last_modified_time = os.path.getmtime(filename)
    else:
        last_modified_time = 0
        last_read_line = 0  

    while True:
        try:
            if os.path.exists(filename):
                current_modified_time = os.path.getmtime(filename)

                if current_modified_time > last_modified_time:
                    print(f"{datetime.now()} - File has been modified. Checking for new data...")
                    last_read_line = load_data_to_db(filename, last_read_line)
                    last_modified_time = current_modified_time
                else:
                    print(f"{datetime.now()} - No new data detected.")

            else:
                print(f"{datetime.now()} - File '{filename}' does not exist. Waiting for file to be created...")
                last_read_line = 0  
                while not os.path.exists(filename):
                    time.sleep(30)  
                print(f"{datetime.now()} - File '{filename}' created. Reading from the beginning...")
                last_modified_time = os.path.getmtime(filename)
                last_read_line = load_data_to_db(filename, last_read_line)

            time.sleep(30)  
        except Exception as e:
            print(f"{datetime.now()} - An error occurred: {e}")
            time.sleep(30)  

if __name__ == "__main__":
    file_path = "data/data.csv"
    monitor_file(file_path)
