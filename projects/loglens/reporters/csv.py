from .base import BaseReporter
import csv

class CSVReporter(BaseReporter):
    def __init__(self, file_name):
        self.file_name = file_name
    
    def report(self, data: dict):
        with open(self.file_name, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            
            # write headers
            writer.writerow(data['headers'])
            
            for row in data['rows']:
                writer.writerow([row[key] for key in data['headers']])