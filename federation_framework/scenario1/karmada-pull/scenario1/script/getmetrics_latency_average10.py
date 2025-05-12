import socket
import requests
import csv
from datetime import datetime, timedelta

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

local_ip = get_local_ip()
PROMETHEUS_RANGE_URL = f"http://{local_ip}:30090/api/v1/query_range"

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
        print("Error querying Prometheus:", resp.status_code, resp.text)
        return []

# 設定時間區間為最近 10 分鐘
end_ts = datetime.now().timestamp()
start_ts = (datetime.now() - timedelta(minutes=10)).timestamp()
step = "30"  # 每 30 秒一個資料點

# PromQL 查詢語句
latency_query = '''
histogram_quantile(0.99,
  sum(rate(apiserver_request_duration_seconds_bucket{job=~"apiserver|kubernetes"}[1m]))
  by (le, verb)
)
'''
qps_query = '''
sum(rate(apiserver_request_total{job=~"apiserver|kubernetes"}[1m])) by (verb)
'''

latency_results = query_prometheus_range(latency_query.strip(), start_ts, end_ts, step)
qps_results = query_prometheus_range(qps_query.strip(), start_ts, end_ts, step)

# 整理 latency 結果
latency_dict = {}
for series in latency_results:
    verb = series['metric'].get('verb', 'N/A')
    for _, value in series['values']:
        try:
            latency_dict.setdefault(verb, []).append(float(value) * 1000)  # 秒轉毫秒
        except:
            pass

# 整理 QPS 結果
qps_dict = {}
for series in qps_results:
    verb = series['metric'].get('verb', 'N/A')
    for _, value in series['values']:
        try:
            qps_dict.setdefault(verb, []).append(float(value))
        except:
            pass

# 平均化並輸出
csv_file = "/root/apiserver_metrics_avg_10min.csv"
with open(csv_file, mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["verb", "avg_p99_latency_ms", "avg_qps"])
    all_verbs = set(latency_dict.keys()) | set(qps_dict.keys())
    for verb in sorted(all_verbs):
        latencies = latency_dict.get(verb, [])
        qps_values = qps_dict.get(verb, [])
        avg_latency = sum(latencies) / len(latencies) if latencies else 0
        avg_qps = sum(qps_values) / len(qps_values) if qps_values else 0
        writer.writerow([verb, f"{avg_latency:.2f}", f"{avg_qps:.2f}"])

print("API server p99 latency and QPS average (last 10min) saved to:", csv_file)