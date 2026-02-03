from typing import Optional, Dict, Any
from .parsers.base import BaseParser
from .parsers.apache import ApacheParser

class CLI:
    PARSERS = {
        'apache': ApacheParser,
    }
    
    @classmethod
    def run(cls, log_type: str, line: str) -> Optional[Dict[str, Any]]:
        parser = cls.PARSERS.get(log_type)
        
        if not parser:
            print(f"Unsupported log type {log_type}")
            return None
            
        return parser.parse(line)