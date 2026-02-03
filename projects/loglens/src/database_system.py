import sqlite3

class DatabaseManager:
    def __init__(self):
        self.connection = sqlite3.connect('data.db')  # connect to an existing database or create a new one
        
    def create_tables(self):
        cursor = self.connection.cursor()
        
        # Create the 'users' table if it doesn't exist
        cursor.execute("""CREATE TABLE IF NOT EXISTS users (
                        id INTEGER PRIMARY KEY, 
                        name TEXT, 
                        email TEXT)
                     """)
    def get_all_users(self):
        cursor = self.connection.cursor()
        
        # Fetch all users from the 'users' table
        rows = cursor.execute("SELECT * FROM users").fetchall()
        return [{'id': row[0], 'name': row[1], 'email': row[2]} for row in rows]