import requests
from sqlite3 import connect
import configparser
from json import loads

class DataFetcher:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.connection = None
        
    def load_settings(self, filepath):
        self.config.read(filepath)   # read the configuration from the specified INI file
    
    def connect_db(self, db_name):
        self.connection = connect(db_name)  # create a new database or connect to an existing one
        
    def fetch_data(self, url):
        response = requests.get(url)   # make HTTP GET request to the API
        if response.status_code == 200:
            return loads(response.text)  # parse JSON data into Python objects
        else:
            print("Failed to fetch data from the API")
    
    def create_tables(self):
        cursor = self.connection.cursor()
        
        # Create the 'users' table if it doesn't exist
        cursor.execute("""CREATE TABLE IF NOT EXISTS users (
                            id INTEGER PRIMARY KEY, 
                            name TEXT, 
                            email TEXT)
                        """)