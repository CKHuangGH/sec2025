from kubernetes import client, config, watch
import time

# -----------------------
# Parameters
# -----------------------
NAMESPACE = "liqo-demo"
TIME_LOG_FILE = "time.txt"

# Load kubeconfig
config.load_kube_config()
v1 = client.CoreV1Api()
w = watch.Watch()

running_pods = set()

print(f"📡 Watching namespace `{NAMESPACE}` until all Running pods disappear...")

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

    if count == 0:
        current_time = time.time()
        print(f"✅ All Running pods are gone. Timestamp: {current_time}")
        with open(TIME_LOG_FILE, "a") as f:
            f.write(f"timeforzero {current_time}\n")
        w.stop()