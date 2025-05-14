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
    """Calculate mean of durations in seconds and convert to milliseconds."""
    if not values:
        return 0.0
    return sum(values) / len(values) * 1000

def avg(values):
    """Calculate arithmetic mean of a list of numbers."""
    if not values:
        return 0.0
    return sum(values) / len(values)

# Time window and step for Prometheus queries
WINDOW   = timedelta(minutes=10)
STEP     = "5s"
now      = datetime.now()
end_ts   = int(now.timestamp())
start_ts = int((now - WINDOW).timestamp())

# Build Prometheus API URL
local_ip             = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

# Jobs to query
jobs = [
    "kube-controller-manager",
    "karmada-controller-manager",
]

# Define the metrics we want to collect
metric_types = {
    # work duration latency metrics
    'p99_work': """
      histogram_quantile(0.99,
        sum(rate(workqueue_work_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'p50_work': """
      histogram_quantile(0.50,
        sum(rate(workqueue_work_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'avg_work': """
      sum(rate(workqueue_work_duration_seconds_sum{{job="{job}"}}[1m]))
      by (name)
      /
      sum(rate(workqueue_work_duration_seconds_count{{job="{job}"}}[1m]))
      by (name)
    """,
    'rate_work': """
      sum(rate(workqueue_work_duration_seconds_count{{job="{job}"}}[1m]))
      by (name)
    """,

    # queue latency metrics
    'p99_queue': """
      histogram_quantile(0.99,
        sum(rate(workqueue_queue_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'p50_queue': """
      histogram_quantile(0.50,
        sum(rate(workqueue_queue_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'avg_queue': """
      sum(rate(workqueue_queue_duration_seconds_sum{{job="{job}"}}[1m]))
      by (name)
      /
      sum(rate(workqueue_queue_duration_seconds_count{{job="{job}"}}[1m]))
      by (name)
    """,

    # retry rate metric
    'rate_retries': """
      sum(rate(workqueue_retries_total{{job="{job}"}}[1m]))
      by (name)
    """,

    # average queue depth over the last minute
    'avg_depth': """
      avg_over_time(workqueue_depth{{job="{job}"}}[1m])
      by (name)
    """
}

# Construct PromQL queries for each job and metric
queries = {}
for job in jobs:
    for mtype, tmpl in metric_types.items():
        key = f"{job}-{mtype}"
        queries[key] = tmpl.format(job=job)

# Fetch raw data from Prometheus
raw = {
    metric_key: query_prometheus_range(q, start_ts, end_ts, STEP)
    for metric_key, q in queries.items()
}

# Parse data into parsed[job][metric_type] = { controller_name: [values] }
parsed = {job: {mt: {} for mt in metric_types} for job in jobs}
for metric_key, series_list in raw.items():
    # Split from the right to keep the full job name intact
    job, mtype = metric_key.rsplit('-', 1)
    target = parsed[job][mtype]
    for series in series_list:
        name = series['metric'].get('name', 'N/A')
        for _, v in series['values']:
            try:
                f = float(v)
                if math.isnan(f):
                    continue
                target.setdefault(name, []).append(f)
            except (ValueError, TypeError):
                continue

# Write results to CSV, skipping controllers with zero work rate
output = "/root/controller_extended_metrics.csv"
with open(output, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow([
        "job", "name",
        "p99_work_ms", "p50_work_ms", "avg_work_ms", "rate_work_per_sec",
        "p99_queue_ms", "p50_queue_ms", "avg_queue_ms",
        "rate_retries_per_sec", "avg_depth"
    ])

    for job in jobs:
        all_names = set().union(*parsed[job].values())
        for name in sorted(all_names):
            work_rate = avg(parsed[job]['rate_work'].get(name, []))
            if work_rate == 0.0:
                # skip inactive controllers
                continue

            p99_work     = avg_ms(parsed[job]['p99_work'].get(name, []))
            p50_work     = avg_ms(parsed[job]['p50_work'].get(name, []))
            avg_work     = avg_ms(parsed[job]['avg_work'].get(name, []))

            p99_queue    = avg_ms(parsed[job]['p99_queue'].get(name, []))
            p50_queue    = avg_ms(parsed[job]['p50_queue'].get(name, []))
            avg_queue    = avg_ms(parsed[job]['avg_queue'].get(name, []))

            retry_rate   = avg(parsed[job]['rate_retries'].get(name, []))
            avg_depth    = avg(parsed[job]['avg_depth'].get(name, []))

            writer.writerow([
                job,
                name,
                f"{p99_work:.2f}",
                f"{p50_work:.2f}",
                f"{avg_work:.2f}",
                f"{work_rate:.2f}",
                f"{p99_queue:.2f}",
                f"{p50_queue:.2f}",
                f"{avg_queue:.2f}",
                f"{retry_rate:.2f}",
                f"{avg_depth:.2f}"
            ])

print("Extended controller metrics written to:", output)