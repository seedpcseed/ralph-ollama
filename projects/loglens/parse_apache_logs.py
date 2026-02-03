import re
from collections import Counter

def read_log(filepath):
    with open(filepath, 'r') as file:
        return [line for line in file]

def extract_info(lines):
    ip_list = []
    method_list = []
    
    for line in lines:
        # Extract IP address using regex.
        ip_match = re.search(r"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}", line)
        if ip_match is not None:
            ip_list.append(ip_match.group())
        
        # Extract HTTP method using regex.
        method_match = re.search(r"\] \"(POST|GET|PUT|DELETE)", line)
        if method_match is not None:
            method_list.append(method_match.group(1))
            
    return ip_list, method_list

def count_info(ip_list, method_list):
    return Counter(ip_list), Counter(method_list)

def display_counts(counter_dict):
    for item, count in counter_dict.items():
        print(f"{item}: {count}")
        
if __name__ == "__main__":
    filepath = 'path/to/your/logfile'  # Replace with your log file path.
    
    lines = read_log(filepath)
    ip_list, method_list = extract_info(lines)
    
    ip_counter, method_counter = count_info(ip_list, method_list)
    
    print("IP Addresses:")
    display_counts(ip_counter)
    
    print("\nHTTP Methods:")
    display_counts(method_counter)