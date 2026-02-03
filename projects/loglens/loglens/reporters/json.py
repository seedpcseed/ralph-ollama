from typing import Dict, Any
import json

class JsonReporter:
    def __init__(self):
        self.report = {}

    def add_section(self, title: str, data: Dict[str, Any]):
        self.report[title] = data

    def write(self, path: str):
        with open(path, 'w') as f:
            json.dump(self.report, f)