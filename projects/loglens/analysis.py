from parsers import parse_apache
import json
import csv

def analyze_logs(files, format):
    results = []
    for file in files:
        if 'access.log' in file:  # Assume Apache logs for this example
            results += parse_apache(file)
            
    # Format the output based on the user's choice
    if format == 'json':
        return json.dumps(results, indent=2)
    elif format == 'csv':
        output = []
        for entry in results:
            output.append([entry['ip'], entry['date'], entry['method']])
        return csv.writer(output).write()