from abc import ABC, abstractmethod

class BaseReporter(ABC):
    @abstractmethod
    def report(self, data: dict) -> None:
        pass
    
class ConsoleReporter(BaseReporter):
    # Implement console output logic here
    pass

class HTMLReporter(BaseReporter):
    # Implement HTML report generation logic here
    pass