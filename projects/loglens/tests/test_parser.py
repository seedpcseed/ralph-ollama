from parsers.syslog import SyslogParser
import datetime

def test_parse_line():
    parser = SyslogParser()
    
    # Test a typical syslog line
    line = '<34>1 2003-10-11T22:14:15.003Z mymachine.example.com su - ID47 - BOM\'su root\' failed for lonvick on /dev/pts/8'
    result = parser._parse_line(line)
    
    assert result['priority'] == 34
    assert result['timestamp'].year == 2003 and result['timestamp'].month == 10 and result['timestamp'].day == 11
    #... and so on for the other fields