import unittest
from datetime import datetime
from loglens.parsers.apache import ApacheLogParser

class TestApacheLogParser(unittest.TestCase):
    def setUp(self):
        self.parser = ApacheLogParser('fixtures/sample_apache.log')
        
    def test_parse_line(self):
        line = '127.0.0.1 user-identifier frank [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200'
        expected = {
            'remote_host': '127.0.0.1',
            'userid': 'user-identifier',
            'username': 'frank',
            'datetime': datetime(2000, 10, 10, 13, 55, 36),
            'method': 'GET',
            'path': '/apache_pb.gif HTTP/1.0',
            'status': 200
        }
        self.assertEqual(self.parser.parse_line(line), expected)