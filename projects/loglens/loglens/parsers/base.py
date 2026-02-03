from abc import ABC, abstractmethod
from .base import AnalyzerInterface

class ParserBase(ABC):
    @abstractmethod
    def parse(self):
        pass