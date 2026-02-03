import requests
import json

def fetch_and_parse():
    response = requests.get('https://api.github.com')  # replace with your API endpoint
    
    if response.status_code == 200:
        data = json.loads(response.text)
        return data
    else:
        print("Failed to fetch data from the server")