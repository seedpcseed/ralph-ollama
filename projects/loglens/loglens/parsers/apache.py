import re
from typing import Optional, Dict, Any

class ApacheParser:
    # Common Log Format pattern
    COMMON_LOG_FORMAT = r'^(\S+) (\S+) (\S+) \[([^\]]+)\] "([A-Z]+) ([^\"]+)? HTTP/[0-9.]+" ([0-9]{3}) ([0-9]+|-)'

    @classmethod
    def parse(cls, line: str) -> Optional[Dict[str, Any]]:
        match = re.match(cls.COMMON_LOG_FORMAT, line)
        
        if not match:
            return None
        
        groups = match.groups()
        
        return {
            'remote_host': groups[0],
            'rfc931': groups[1],
            'authuser': groups[2],
            'date': cls._parse_date(groups[3]),
            'request_method': groups[4],
            'path': groups[5],
            'status': int(groups[6]),
            'bytes_sent': int(groups[7]) if groups[7] != '-' else 0,
        }
    
    @staticmethod
    def _parse_date(date: str) -> Optional[str]:
        # Example date format: 26/May/2019:17:35:18 +0000
        return date.split(':')[0] if date else None