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

# === 時間設定 ===
WINDOW   = timedelta(minutes=10)
STEP     = "5s"
now      = datetime.now()
end_ts   = int(now.timestamp())
start_ts = int((now - WINDOW).timestamp())

# === Prometheus API URL ===
local_ip            = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

# === 需要查詢的 jobs ===
jobs = [
    "kube-controller-manager",
    "karmada-controller-manager",
]

# === 定義各種 metric 的 PromQL 範本 ===
metric_types = {
    'p99': """
      histogram_quantile(0.99,
        sum(rate(workqueue_work_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'p50': """
      histogram_quantile(0.50,
        sum(rate(workqueue_work_duration_seconds_bucket{{job="{job}"}}[1m]))
        by (le, name)
      )
    """,
    'avg': """
      sum(rate(workqueue_work_duration_seconds_sum{{job="{job}"}}[1m]))
      by (name)
      /
      sum(rate(workqueue_work_duration_seconds_count{{job="{job}"}}[1m]))
      by (name)
    """,
    'rate': """
      sum(rate(workqueue_work_duration_seconds_count{{job="{job}"}}[1m]))
      by (name)
    """
}

# === 組合所有 job 與 metric 的 queries ===
queries = {}
for job in jobs:
    for mtype, tmpl in metric_types.items():
        key = f"{job}-{mtype}"
        queries[key] = tmpl.format(job=job)

# === 從 Prometheus 抓取原始資料 ===
raw = {
    metric_key: query_prometheus_range(q, start_ts, end_ts, STEP)
    for metric_key, q in queries.items()
}

# === 解析資料結構：parsed[job][metric_type] = { name: [values] } ===
parsed = {job: {mt: {} for mt in metric_types} for job in jobs}

for metric_key, series_list in raw.items():
    # 後 rsplit 一次，保留完整 job 名稱
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

# === 寫入 CSV，並跳過 rate 平均為 0 的 controller ===
output = "/root/controller_metrics_active.csv"
with open(output, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["job", "name", "p99_ms", "p50_ms", "avg_ms", "rate_per_sec"])

    for job in jobs:
        all_names = set().union(*parsed[job].values())
        for name in sorted(all_names):
            rate_vals = parsed[job]['rate'].get(name, [])
            avg_rate  = avg(rate_vals)
            if avg_rate == 0.0:
                continue

            p99_ms     = avg_ms(parsed[job]['p99'].get(name, []))
            p50_ms     = avg_ms(parsed[job]['p50'].get(name, []))
            avg_lat_ms = avg_ms(parsed[job]['avg'].get(name, []))

            writer.writerow([
                job,
                name,
                f"{p99_ms:.2f}",
                f"{p50_ms:.2f}",
                f"{avg_lat_ms:.2f}",
                f"{avg_rate:.2f}"
            ])

print("Active controllers metrics written to:", output)