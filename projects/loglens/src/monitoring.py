from prometheus_client import start_http_server, Counter, Gauge
import random
import time

REQUESTS = Counter('my_app_requests_total', 'Total number of requests to my app')
INPROGRESS = Gauge('my_app_inprogress', 'Number of in-progress requests to my app')
LAST = Gauge('my_app_last_time_seconds', 'The last time a request was served')

def process_request():
    INPROGRESS.inc()
    REQUESTS.inc()
    
    start = time.time()
    # Simulate work by sleeping for 500ms to 2s
    time.sleep(random.uniform(0.5, 2))
    
    LAST.set_to_current_time()
    INPROGRESS.dec()

if __name__ == '__main__':
    start_http_server(8000)   # Expose Prometheus metrics on port 8000
    while True:   # Simulate incoming requests by calling process_request() every second
        process_request()
        time.sleep(1)