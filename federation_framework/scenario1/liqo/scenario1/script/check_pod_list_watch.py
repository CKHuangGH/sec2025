from kubernetes import client, config, watch
import sys
import time

# -----------------------
# Parameters
# -----------------------
TARGET_COUNT = int(sys.argv[1]) if len(sys.argv) > 1 else 10
NAMESPACE = "liqo-demo"
TIME_LOG_FILE = "time.txt"

# Load kubeconfig (use load_incluster_config() if running inside a cluster)
config.load_kube_config()
v1 = client.CoreV1Api()
w = watch.Watch()

running_pods = set()

print(f"📡 Watching namespace `{NAMESPACE}` for Running pods. Target count: {TARGET_COUNT}")

for event in w.stream(v1.list_namespaced_pod, namespace=NAMESPACE, timeout_seconds=0):
    pod = event["object"]
    name = pod.metadata.name
    phase = pod.status.phase
    event_type = event["type"]

    if event_type in ["ADDED", "MODIFIED"]:
        if phase == "Running":
            running_pods.add(name)
        else:
            running_pods.discard(name)
    elif event_type == "DELETED":
        running_pods.discard(name)

    count = len(running_pods)
    print(f"[{event_type}] Pod: {name}, Phase: {phase}, Current Running count: {count}")

    if count >= TARGET_COUNT:
        current_time = time.time()  # e.g., 1721765861.5972943
        print(f"✅ Target reached: {count} Running pods. Timestamp: {current_time}")
        with open(TIME_LOG_FILE, "a") as f:
            f.write(f"timeforpods {current_time}\n")
        w.stop()