import socket
import requests
import csv
import math
from datetime import datetime, timedelta

def get_local_ip():
    """Get the local IP by opening a UDP socket—no packets actually sent."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()

def query_prometheus_range(query, start, end, step):
    """
    Run a Prometheus `query_range` against the local kube-prometheus.
    Returns the JSON list of series, each with 'metric' and 'values'.
    """
    resp = requests.get(PROMETHEUS_RANGE_URL, params={
        'query': query, 'start': start, 'end': end, 'step': step
    })
    if resp.status_code != 200:
        print(f"[Error] Prometheus query failed ({resp.status_code}): {resp.text}")
        return []
    return resp.json()['data']['result']

def avg_ms(values):
    """
    Mean of a list of durations in seconds, converted to milliseconds.
    Returns 0.0 if list empty.
    """
    if not values:
        return 0.0
    return sum(values) / len(values) * 1000

def avg(values):
    """
    Arithmetic mean of a list of numbers.
    Returns 0.0 if list empty.
    """
    if not values:
        return 0.0
    return sum(values) / len(values)

WINDOW   = timedelta(minutes=10)
STEP     = "5s"
now      = datetime.now()
end_ts   = int(now.timestamp())
start_ts = int((now - WINDOW).timestamp())

local_ip            = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

queries = {
    'p99': """
      histogram_quantile(0.99,
        sum(rate(workqueue_work_duration_seconds_bucket{job="kube-controller-manager"}[1m]))
        by (le, name)
      )
    """,
    'p50': """
      histogram_quantile(0.50,
        sum(rate(workqueue_work_duration_seconds_bucket{job="kube-controller-manager"}[1m]))
        by (le, name)
      )
    """,
    'avg': """
      sum(rate(workqueue_work_duration_seconds_sum{job="kube-controller-manager"}[1m]))
      by (name)
      /
      sum(rate(workqueue_work_duration_seconds_count{job="kube-controller-manager"}[1m]))
      by (name)
    """,
    'rate': """
      sum(rate(workqueue_work_duration_seconds_count{job="kube-controller-manager"}[1m]))
      by (name)
    """
}

raw = { metric: query_prometheus_range(q, start_ts, end_ts, STEP)
        for metric, q in queries.items() }

parsed = {}
for metric, series_list in raw.items():
    d = {}
    for series in series_list:
        name = series['metric'].get('name', 'N/A')
        for _, v in series['values']:
            try:
                f = float(v)
                # skip NaN values so average/quantiles become 0 if no real samples
                if math.isnan(f):
                    continue
                d.setdefault(name, []).append(f)
            except (ValueError, TypeError):
                continue
    parsed[metric] = d

output = "/root/controller_metrics_active.csv"
with open(output, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["name", "p99_ms", "p50_ms", "avg_ms", "rate_per_sec"])

    # gather all controller names seen
    all_names = set().union(*parsed.values())

    for name in sorted(all_names):
        rate_vals = parsed['rate'].get(name, [])
        avg_rate  = avg(rate_vals)
        # skip if average reconcile rate is zero → inactive controller
        if avg_rate == 0.0:
            continue

        # compute latencies in ms
        p99_ms    = avg_ms(parsed['p99'].get(name, []))
        p50_ms    = avg_ms(parsed['p50'].get(name, []))
        avg_lat_ms= avg_ms(parsed['avg'].get(name, []))

        writer.writerow([
            name,
            f"{p99_ms:.2f}",
            f"{p50_ms:.2f}",
            f"{avg_lat_ms:.2f}",
            f"{avg_rate:.2f}"
        ])

print("Active controllers metrics written to:", output)