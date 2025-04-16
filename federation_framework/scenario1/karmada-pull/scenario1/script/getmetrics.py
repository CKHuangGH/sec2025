import socket
import requests
import csv
from datetime import datetime, timedelta

def get_local_ip():
    """Get the local (non-loopback) IP address, typically used in LAN environments"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

# Get the local IP address, assuming Prometheus is running on this machine
local_ip = get_local_ip()

# Prometheus query_range API URL
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

def query_prometheus_range(query, start, end, step):
    """
    Query historical data from Prometheus using the query_range API
    :param query: Prometheus query expression
    :param start: Start time for the query (Unix timestamp)
    :param end: End time for the query (Unix timestamp)
    :param step: Interval in seconds between data points
    :return: The 'data.result' part of the JSON response
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

# Modify query: remove namespace="karmada-system" to include data from all namespaces
cpu_query = 'rate(container_cpu_usage_seconds_total{container!=""}[1m])'
memory_query = 'container_memory_working_set_bytes{container!=""}'

# Define time range: fetch the past 20 minutes with one data point every 10 seconds
end_time = datetime.now()
start_time = end_time - timedelta(minutes=20)
start_ts = start_time.timestamp()
end_ts = end_time.timestamp()
step = "10"  # Interval of 10 seconds between data points

# Query CPU and memory metrics
cpu_results = query_prometheus_range(cpu_query, start_ts, end_ts, step)
memory_results = query_prometheus_range(memory_query, start_ts, end_ts, step)

# Parse CPU data: convert to millicores (m)
# Use key as (namespace, pod, timestamp)
cpu_dict = {}
for series in cpu_results:
    pod = series['metric'].get('pod', 'N/A')
    namespace = series['metric'].get('namespace', 'N/A')
    for t, value in series['values']:
        try:
            cpu_dict[(namespace, pod, t)] = float(value) * 1000  # cores → millicores
        except Exception as e:
            cpu_dict[(namespace, pod, t)] = None

# Parse memory data: convert to MiB
mem_dict = {}
for series in memory_results:
    pod = series['metric'].get('pod', 'N/A')
    namespace = series['metric'].get('namespace', 'N/A')
    for t, value in series['values']:
        try:
            mem_dict[(namespace, pod, t)] = float(value) / (1024**2)  # bytes → MiB
        except Exception as e:
            mem_dict[(namespace, pod, t)] = None

# Merge CPU and memory data using union of all (namespace, pod, timestamp) combinations
all_keys = set(cpu_dict.keys()) | set(mem_dict.keys())

# Write data to CSV: columns include Unix timestamp, namespace, pod, cpu_m, memory_MiB
csv_file = "metrics_20min_dense.csv"
with open(csv_file, mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(["timestamp", "namespace", "pod", "cpu_m", "memory_MiB"])
    # Sort by timestamp, namespace, and pod name
    sorted_keys = sorted(all_keys, key=lambda x: (float(x[2]), x[0], x[1]))
    for ns, pod, t in sorted_keys:
        timestamp_unix = float(t)
        cpu_val = cpu_dict.get((ns, pod, t), "")
        mem_val = mem_dict.get((ns, pod, t), "")
        writer.writerow([timestamp_unix, ns, pod, cpu_val, mem_val])

print("Data collection complete. CSV file saved as:", csv_file)
