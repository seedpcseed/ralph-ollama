from dataclasses import dataclass
from datetime import datetime

@dataclass
class LogEntry:
    ip_address: str = ""
    timestamp: datetime = None
    method: str = ""
    uri: str = ""
    status_code: int = 0
    user_agent: str = ""