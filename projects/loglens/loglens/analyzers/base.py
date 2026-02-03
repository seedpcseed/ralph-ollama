from abc import ABC, abstractmethod

class AnalyzerInterface(ABC):
    @abstractmethod
    def analyze(self):
        pass