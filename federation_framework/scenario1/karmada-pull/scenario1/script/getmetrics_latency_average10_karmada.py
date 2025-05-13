import socket
import requests
import csv
from datetime import datetime, timedelta

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Used only to retrieve the local IP; no actual packet is sent to the target
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

def query_prometheus_range(query, start, end, step):
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
        print(f"[Error] Prometheus query failed ({resp.status_code}): {resp.text}")
        return []

def avg_ms(lst):
    """Takes a list of latency values in seconds, returns the average in milliseconds"""
    return sum(lst) / len(lst) * 1000 if lst else 0

def avg(lst):
    """Takes a list of numeric values, returns the average"""
    return sum(lst) / len(lst) if lst else 0

# --- Initialize Prometheus API endpoint and time range ---
local_ip = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

now = datetime.now()
end_ts = int(now.timestamp())
start_ts = int((now - timedelta(minutes=10)).timestamp())
step = "5s"  # One data point every 5 seconds

# --- PromQL queries ---
latency_q = {
    'kube_p99':   '''
        histogram_quantile(0.99,
          sum(rate(apiserver_request_duration_seconds_bucket{job="kubernetes-apiserver"}[1m]))
          by (le, verb)
        )
    ''',
    'kube_p50':   '''
        histogram_quantile(0.50,
          sum(rate(apiserver_request_duration_seconds_bucket{job="kubernetes-apiserver"}[1m]))
          by (le, verb)
        )
    ''',
    'karmada_p99':'''
        histogram_quantile(0.99,
          sum(rate(apiserver_request_duration_seconds_bucket{job="karmada-apiserver"}[1m]))
          by (le, verb)
        )
    ''',
    'karmada_p50':'''
        histogram_quantile(0.50,
          sum(rate(apiserver_request_duration_seconds_bucket{job="karmada-apiserver"}[1m]))
          by (le, verb)
        )
    ''',
}

qps_q = {
    'kube':   'sum(rate(apiserver_request_total{job="kubernetes-apiserver"}[1m])) by (verb)',
    'karmada':'sum(rate(apiserver_request_total{job="karmada-apiserver"}[1m])) by (verb)',
}

# --- Fetch data ---
results = {}
# latency
for key, q in latency_q.items():
    results[key] = query_prometheus_range(q.strip(), start_ts, end_ts, step)

# qps
for key, q in qps_q.items():
    results[f"qps_{key}"] = query_prometheus_range(q.strip(), start_ts, end_ts, step)

# --- Parse into dict of lists ---
parsed = {}
for name, series_list in results.items():
    d = {}
    for series in series_list:
        verb = series['metric'].get('verb', 'N/A')
        # Pick the numeric value for each timestamp
        for _, val in series['values']:
            try:
                d.setdefault(verb, []).append(float(val))
            except ValueError:
                pass
    parsed[name] = d

# --- Write to CSV ---
csv_file = "/root/apiserver_metrics_avg_10min.csv"
with open(csv_file, mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow([
        "verb",
        "latency_p99_kubernetes_ms",
        "latency_p99_karmada_ms",
        "latency_p50_kubernetes_ms",
        "latency_p50_karmada_ms",
        "avg_qps_kubernetes",
        "avg_qps_karmada"
    ])

    # All possible HTTP verbs
    all_verbs = set()
    for d in parsed.values():
        all_verbs |= set(d.keys())

    for verb in sorted(all_verbs):
        p99_kube  = avg_ms(parsed['kube_p99'].get(verb, []))
        p99_karm  = avg_ms(parsed['karmada_p99'].get(verb, []))
        p50_kube  = avg_ms(parsed['kube_p50'].get(verb, []))
        p50_karm  = avg_ms(parsed['karmada_p50'].get(verb, []))
        qps_kube  = avg(parsed['qps_kube'].get(verb, []))
        qps_karm  = avg(parsed['qps_karmada'].get(verb, []))

        writer.writerow([
            verb,
            f"{p99_kube:.2f}",
            f"{p99_karm:.2f}",
            f"{p50_kube:.2f}",
            f"{p50_karm:.2f}",
            f"{qps_kube:.2f}",
            f"{qps_karm:.2f}"
        ])

print("API server p99/p50 latency and average QPS in the past 10 minutes have been written to:", csv_file)