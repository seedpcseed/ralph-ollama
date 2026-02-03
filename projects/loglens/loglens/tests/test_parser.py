import pytest
from datetime import datetime
from parsers.apache import ApacheLogParser

def test_parse():
    parser = ApacheLogParser()
    
    # Test with a sample log line
    logline = '127.0.0.1 - - [23/Apr/2020:14:38:25 +0200] "GET / HTTP/1.1" 200 612'
    parsed_dict = parser.parse(logline)
    
    assert parsed_dict == {
        'client': '127.0.0.1',
        'user': None,
        'timestamp': datetime(2020, 4, 23, 14, 38, 25),
        'method': 'GET',
        'endpoint': '/',
        'protocol': 'HTTP/1.1',
        'status_code': 200,
        'content_length': 612,
    }