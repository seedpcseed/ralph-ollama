import unittest
from src import database_system

class TestDatabaseManager(unittest.TestCase):
    def setUp(self):
        self.db = database_system.DatabaseManager()
        self.db.create_tables()
        
    def test_get_all_users(self):
        self.assertEqual(self.db.get_all_users(), [])
        
if __name__ == "__main__":
    unittest.main()