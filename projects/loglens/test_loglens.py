def test_apache_parser():
    apache = ApacheParser()
    data = apache.parse('tests/fixtures/example.apache')
    
    # Verify if parsed data is correct
    assert 'example' in data['server']
    
# Similarly for JSONParser and SyslogParser