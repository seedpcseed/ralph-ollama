from datetime import datetime
import re

class ApacheLogParser:
    def __init__(self, date_format='%d/%b/%Y:%H:%M:%S %z'):
        self.date_format = date_format

    def parse(self, logfile):
        with open(logfile) as f:
            for line in f:
                yield self._parse_line(line)

    def _parse_line(self, line):
        match = re.match(r'(\S+) (\S+) (\S+) \[([\w:/]+\s[+\-]\d{4})\] "(.+)" (\d{3}) (\d+)', line)
        if match:
            data = match.groups()
            entry = {
                'ip': data[0],
                'date': datetime.strptime(data[3].replace(' +0000',' UTC'), self.date_format),  # Use provided date format
                'request': data[4],
                'status': int(data[5]),
                'size': int(data[6])
            }
            return entry
        else:
            raise ValueError("Failed to parse line")