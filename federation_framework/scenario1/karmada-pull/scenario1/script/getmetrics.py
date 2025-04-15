import socket
import requests
import csv
from datetime import datetime, timedelta

def get_local_ip():
    """Get the local (non-loopback) IP address, typically used within LAN."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

# Get local IP assuming Prometheus is running on this machine
local_ip = get_local_ip()
# Use the query_range API to fetch historical metrics
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

def query_prometheus_range(query, start, end, step):
    """
    Query Prometheus using the query_range API.
    :param query: Prometheus query string
    :param start: Start time (Unix timestamp)
    :param end: End time (Unix timestamp)
    :param step: Step interval in seconds, controls data density
    :return: List of results from Prometheus in JSON format
    """
    params = {
        'query': query,
        'start': start,
        'end': end,
        'step': step
    }
    response = requests.get(PROMETHEUS_RANGE_URL, params=params)
    if response.status_code == 200:
        result = response.json()
        return result['data']['result']
    else:
        print("Error querying Prometheus:", response.status_code, response.text)
        return []

# Define Prometheus queries
cpu_query = 'rate(container_cpu_usage_seconds_total{namespace="karmada-system", container!=""}[1m])'
memory_query = 'container_memory_working_set_bytes{namespace="karmada-system", container!=""}'

# Define time range: past 20 minutes with dense points (every 10 seconds)
end_time = datetime.now()
start_time = end_time - timedelta(minutes=20)
start_ts = start_time.timestamp()
end_ts = end_time.timestamp()
step = "10"  # 10 seconds per sample point

# Query CPU and memory metrics
cpu_results = query_prometheus_range(cpu_query, start_ts, end_ts, step)
memory_results = query_prometheus_range(memory_query, start_ts, end_ts, step)

# Parse CPU metrics: convert cores to millicores (m)
cpu_dict = {}  # key: (pod, timestamp), value: CPU in millicores
for series in cpu_results:
    pod = series['metric'].get('pod', 'N/A')
    for t, value in series['values']:
        try:
            cpu_dict[(pod, t)] = float(value) * 1000  # cores → millicores
        except Exception as e:
            cpu_dict[(pod, t)] = None

# Parse memory metrics: convert bytes to MiB
mem_dict = {}  # key: (pod, timestamp), value: memory in MiB
for series in memory_results:
    pod = series['metric'].get('pod', 'N/A')
    for t, value in series['values']:
        try:
            mem_dict[(pod, t)] = float(value) / (1024**2)  # bytes → MiB
        except Exception as e:
            mem_dict[(pod, t)] = None

# Merge CPU and memory results by (pod, timestamp)
all_keys = set(cpu_dict.keys()) | set(mem_dict.keys())

# Write to CSV: columns are Unix timestamp, pod, cpu_m, memory_MiB
csv_file = "metrics_20min_dense.csv"
with open(csv_file, mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(["timestamp", "pod", "cpu_m", "memory_MiB"])
    # Sort by timestamp and pod name
    sorted_keys = sorted(all_keys, key=lambda x: (float(x[1]), x[0]))
    for pod, t in sorted_keys:
        timestamp_unix = float(t)
        cpu_val = cpu_dict.get((pod, t), "")
        mem_val = mem_dict.get((pod, t), "")
        writer.writerow([timestamp_unix, pod, cpu_val, mem_val])

print("Data collection complete. CSV file saved as:", csv_file)