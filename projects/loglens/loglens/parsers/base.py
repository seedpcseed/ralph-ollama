from typing import Optional, Dict, Any

class BaseParser:
    @classmethod
    def parse(cls, line: str) -> Optional[Dict[str, Any]]:
        raise NotImplementedError()