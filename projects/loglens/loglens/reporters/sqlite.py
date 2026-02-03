import sqlite3
from sqlite3 import Error

class SQLiteReporter(object):
    def __init__(self, db_file):
        self.db_file = db_file
    
    def create_connection(self):
        conn = None;
        try:
            conn = sqlite3.connect(self.db_file)
            print(sqlite3.version)
        except Error as e:
            print(e)
        return conn