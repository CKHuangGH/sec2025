import socket
import requests
import csv
import re
from datetime import datetime, timedelta

def get_local_ip():
    """Get the local (non-loopback) IP address, typically used in LAN environments."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

# Prometheus query_range API URL
local_ip = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

def query_prometheus_range(query, start, end, step):
    """
    Query historical data from Prometheus using the query_range API.
    
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
    resp = requests.get(PROMETHEUS_RANGE_URL, params=params)
    if resp.status_code == 200:
        return resp.json()['data']['result']
    else:
        print("Error querying Prometheus:", resp.status_code, resp.text)
        return []

# --- Key change: fetch data from the last 10 minutes ---
end_ts = datetime.now().timestamp()
start_ts = (datetime.now() - timedelta(minutes=10)).timestamp()

cpu_query = 'rate(container_cpu_usage_seconds_total{container!="",pod!=""}[1m])'
memory_query = 'container_memory_working_set_bytes{container!="",pod!=""}'
step = "5"  # Collect data points every 5 seconds

cpu_results = query_prometheus_range(cpu_query, start_ts, end_ts, step)
memory_results = query_prometheus_range(memory_query, start_ts, end_ts, step)

# Parse CPU data into millicores
cpu_dict = {}
for series in cpu_results:
    namespace = series['metric'].get('namespace', 'N/A')
    pod = series['metric'].get('pod', 'N/A')
    for timestamp, value in series['values']:
        try:
            cpu_dict.setdefault((namespace, pod), []).append(float(value) * 1000)
        except:
            pass

# Parse Memory data into MiB
mem_dict = {}
for series in memory_results:
    namespace = series['metric'].get('namespace', 'N/A')
    pod = series['metric'].get('pod', 'N/A')
    for timestamp, value in series['values']:
        try:
            mem_dict.setdefault((namespace, pod), []).append(float(value) / (1024**2))
        except:
            pass

# Compute average for each Pod
avg_results = []
for key in set(cpu_dict.keys()) | set(mem_dict.keys()):
    cpu_list = cpu_dict.get(key, [])
    mem_list = mem_dict.get(key, [])
    avg_cpu = sum(cpu_list) / len(cpu_list) if cpu_list else 0
    avg_mem = sum(mem_list) / len(mem_list) if mem_list else 0
    avg_results.append((key[0], key[1], avg_cpu, avg_mem))

# Write averages to CSV
csv_file = "/root/resource_avg_10min.csv"
with open(csv_file, mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["namespace", "pod", "avg_cpu_m", "avg_memory_MiB"])
    for namespace, pod, avg_cpu, avg_mem in sorted(avg_results, key=lambda x: (x[0], x[1])):
        writer.writerow([namespace, pod, f"{avg_cpu:.2f}", f"{avg_mem:.2f}"])

print("10-minute average calculation complete. CSV saved as:", csv_file)=