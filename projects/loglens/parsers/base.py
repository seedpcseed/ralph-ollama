from abc import ABC, abstractmethod
from typing import Dict, List

class BaseParser(ABC):
    @abstractmethod
    def parse(self, log_file: str) -> List[Dict]:
        pass

    @abstractmethod
    def process(self, raw_data: Dict):
        pass