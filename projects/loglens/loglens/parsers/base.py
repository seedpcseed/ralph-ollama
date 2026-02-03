from abc import ABC, abstractmethod
from typing import List

class Parser(ABC):
    @abstractmethod
    def parse_file(self, filepath: str) -> List[dict]:
        pass