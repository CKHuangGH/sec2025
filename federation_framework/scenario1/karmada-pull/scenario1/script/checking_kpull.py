#!/usr/bin/env python3

import argparse
import signal
import sys
import threading
import os
import csv
from datetime import datetime

from kubernetes import client, config, watch

# Global state dictionaries
counts = {}
thresholds = {}
thresholds_reached = {}
pod_phases = {}


def record_event(resource_name, event_type, count, threshold_reached, output_file, lock):
    """
    Print all events to stdout but only write threshold-reaching events to CSV output_file.
    """
    ts = int(datetime.utcnow().timestamp())
    # Print event
    print(f"{resource_name} {event_type} count={count} ts={ts}")

    # Only record threshold reached events to CSV
    if output_file and event_type == 'THRESHOLD_REACHED':
        with lock:
            # Ensure CSV header exists
            write_header = not os.path.exists(output_file) or os.path.getsize(output_file) == 0
            with open(output_file, 'a', newline='') as f:
                writer = csv.writer(f)
                if write_header:
                    writer.writerow(['resource', 'event', 'count', 'timestamp'])
                writer.writerow([resource_name, event_type, count, ts])

    # Return updated threshold flag
    return threshold_reached or (event_type == 'THRESHOLD_REACHED')


def watch_resource(resource_name, list_func, namespace, initial_rv, output_file, lock, stop_event):
    w = watch.Watch()
    try:
        for event in w.stream(list_func, namespace=namespace, resource_version=initial_rv):
            # Exit if stop has been signaled
            if stop_event.is_set():
                break

            etype = event['type']
            count = counts[resource_name]
            if etype == 'ADDED':
                count += 1
            elif etype == 'DELETED':
                count -= 1
            else:
                continue

            counts[resource_name] = count
            # Check threshold
            if not thresholds_reached[resource_name] and count >= thresholds[resource_name]:
                thresholds_reached[resource_name] = True
                record_event(resource_name, 'THRESHOLD_REACHED', count, True, output_file, lock)

                # If all thresholds are reached, signal stop
                if all(thresholds_reached.values()):
                    stop_event.set()
                    break
    except Exception as e:
        with lock:
            print(f"Error watching {resource_name}: {e}")
    finally:
        w.stop()


def watch_running_pods(namespace, v1, initial_rv, output_file, lock, stop_event):
    w = watch.Watch()
    global counts, thresholds, thresholds_reached, pod_phases
    running = counts['POD']
    try:
        for event in w.stream(v1.list_namespaced_pod, namespace=namespace, resource_version=initial_rv):
            # Exit if stop has been signaled
            if stop_event.is_set():
                break

            pod = event['object']
            uid = pod.metadata.uid
            new_phase = pod.status.phase
            old_phase = pod_phases.get(uid)
            etype = event['type']

            if etype == 'ADDED':
                pod_phases[uid] = new_phase
                if new_phase == 'Running':
                    running += 1
            elif etype == 'DELETED':
                if old_phase == 'Running':
                    running -= 1
                pod_phases.pop(uid, None)
            elif etype == 'MODIFIED':
                if old_phase != 'Running' and new_phase == 'Running':
                    running += 1
                elif old_phase == 'Running' and new_phase != 'Running':
                    running -= 1
                pod_phases[uid] = new_phase
            else:
                continue

            counts['POD'] = running
            # Check threshold
            if not thresholds_reached['POD'] and running >= thresholds['POD']:
                thresholds_reached['POD'] = True
                record_event('POD', 'THRESHOLD_REACHED', running, True, output_file, lock)

                # If all thresholds are reached, signal stop
                if all(thresholds_reached.values()):
                    stop_event.set()
                    break
    except Exception as e:
        with lock:
            print(f"Error watching RUNNING PODs: {e}")
    finally:
        w.stop()


def main():
    parser = argparse.ArgumentParser(
        description='Monitor running pods, services, and serviceaccounts; record when thresholds reached'
    )
    parser.add_argument('--namespace', '-n', default='default', help='Namespace to monitor')
    parser.add_argument('--pod-threshold', type=int, required=True, help='Running pod count threshold')
    parser.add_argument('--svc-threshold', type=int, required=True, help='Service count threshold')
    parser.add_argument('--sa-threshold', type=int, required=True, help='ServiceAccount count threshold')
    parser.add_argument('--output-file', '-o', default='/root/timestamp.csv', help='CSV file to record threshold events')
    args = parser.parse_args()

    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()

    v1 = client.CoreV1Api()
    lock = threading.Lock()
    stop_event = threading.Event()  # Event to signal watchers to stop

    # Handle SIGINT/SIGTERM
    def handle_signal(signum, frame):
        print(f"Received signal {signum}, exiting")
        stop_event.set()
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    global counts, thresholds, thresholds_reached, pod_phases
    # Initialize thresholds and state
    thresholds = {
        'POD': args.pod_threshold,
        'SVC': args.svc_threshold,
        'SA': args.sa_threshold
    }
    thresholds_reached = {k: False for k in thresholds}
    pod_phases = {}

    # Initial pods: count only Running
    pods = v1.list_namespaced_pod(namespace=args.namespace)
    for pod in pods.items:
        pod_phases[pod.metadata.uid] = pod.status.phase
    running_count = sum(1 for phase in pod_phases.values() if phase == 'Running')
    counts['POD'] = running_count
    rv_p = pods.metadata.resource_version
    if running_count >= thresholds['POD']:
        thresholds_reached['POD'] = True
        record_event('POD', 'THRESHOLD_REACHED', running_count, True, args.output_file, lock)

    # Initial services
    svcs = v1.list_namespaced_service(namespace=args.namespace)
    counts['SVC'] = len(svcs.items)
    rv_svc = svcs.metadata.resource_version
    if counts['SVC'] >= thresholds['SVC']:
        thresholds_reached['SVC'] = True
        record_event('SVC', 'THRESHOLD_REACHED', counts['SVC'], True, args.output_file, lock)

    # Initial serviceaccounts
    sas = v1.list_namespaced_service_account(namespace=args.namespace)
    counts['SA'] = len(sas.items)
    rv_sa = sas.metadata.resource_version
    if counts['SA'] >= thresholds['SA']:
        thresholds_reached['SA'] = True
        record_event('SA', 'THRESHOLD_REACHED', counts['SA'], True, args.output_file, lock)

    # Start watcher threads
    threads = [
        threading.Thread(
            target=watch_running_pods,
            args=(args.namespace, v1, rv_p, args.output_file, lock, stop_event)
        ),
        threading.Thread(
            target=watch_resource,
            args=('SVC', v1.list_namespaced_service, args.namespace, rv_svc, args.output_file, lock, stop_event)
        ),
        threading.Thread(
            target=watch_resource,
            args=('SA', v1.list_namespaced_service_account, args.namespace, rv_sa, args.output_file, lock, stop_event)
        )
    ]

    for t in threads:
        t.daemon = True
        t.start()

    # Wait until stop_event is set
    stop_event.wait()

    # Join threads and exit
    for t in threads:
        t.join()


if __name__ == '__main__':
    main()