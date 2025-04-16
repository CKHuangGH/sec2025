#!/usr/bin/env python3

import argparse
import signal
import sys
import threading
from datetime import datetime

from kubernetes import client, config, watch


def record_event(resource_name, event_type, count, threshold_reached, output_file, lock):
    ts = int(datetime.utcnow().timestamp())
    line = f"{resource_name} {event_type} count={count} ts={ts}\n"
    with lock:
        print(line.strip())
        if output_file:
            with open(output_file, 'a') as f:
                f.write(line)
    # Return updated threshold flag
    if not threshold_reached and count >= thresholds[resource_name]:
        record_event(resource_name, 'THRESHOLD_REACHED', count, True, output_file, lock)
        return True
    return threshold_reached


def watch_resource(resource_name, list_func, namespace, initial_rv, output_file, lock):
    w = watch.Watch()
    try:
        for event in w.stream(list_func, namespace=namespace, resource_version=initial_rv):
            etype = event['type']
            # Get count storage and threshold
            count = counts[resource_name]
            if etype == 'ADDED':
                count += 1
            elif etype == 'DELETED':
                count -= 1
            else:
                continue
            counts[resource_name] = count
            # Record added/deleted
            record_event(resource_name, etype, count, thresholds_reached[resource_name], output_file, lock)
            # Update threshold flag
            if not thresholds_reached[resource_name] and count >= thresholds[resource_name]:
                thresholds_reached[resource_name] = True
            # Always log decrease
            if etype == 'DELETED':
                record_event(resource_name, 'COUNT_DECREASED', count, True, output_file, lock)
    except Exception as e:
        with lock:
            print(f"Error watching {resource_name}: {e}")
    finally:
        w.stop()


def main():
    parser = argparse.ArgumentParser(
        description='Monitor pods, services, and serviceaccounts; record when thresholds reached and detect decreases'
    )
    parser.add_argument('--namespace', '-n', default='default', help='Namespace to monitor')
    parser.add_argument('--pod-threshold', type=int, required=True, help='Pod count threshold')
    parser.add_argument('--svc-threshold', type=int, required=True, help='Service count threshold')
    parser.add_argument('--sa-threshold', type=int, required=True, help='ServiceAccount count threshold')
    parser.add_argument('--output-file', '-o', default=None, help='File to append Unix timestamp logs')
    args = parser.parse_args()

    # Load Kubernetes config
    try:
        config.load_incluster_config()
    except config.ConfigException:
        config.load_kube_config()

    v1 = client.CoreV1Api()
    lock = threading.Lock()

    # Handle shutdown
    def handle_signal(signum, frame):
        print(f"Received signal {signum}, exiting")
        sys.exit(0)
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    global counts, thresholds, thresholds_reached
    counts = {}
    thresholds = {
        'POD': args.pod_threshold,
        'SVC': args.svc_threshold,
        'SA': args.sa_threshold
    }
    thresholds_reached = {k: False for k in thresholds}

    # Initial list and resourceVersion for each resource
    pods = v1.list_namespaced_pod(namespace=args.namespace)
    counts['POD'] = len(pods.items)
    rv_p = pods.metadata.resource_version
    svcs = v1.list_namespaced_service(namespace=args.namespace)
    counts['SVC'] = len(svcs.items)
    rv_svc = svcs.metadata.resource_version
    sas = v1.list_namespaced_service_account(namespace=args.namespace)
    counts['SA'] = len(sas.items)
    rv_sa = sas.metadata.resource_version

    # Log initial counts and threshold hits
    for res in ['POD', 'SVC', 'SA']:
        record_event(res, 'INITIAL_COUNT', counts[res], False, args.output_file, lock)
        if counts[res] >= thresholds[res]:
            thresholds_reached[res] = True
            record_event(res, 'THRESHOLD_REACHED', counts[res], True, args.output_file, lock)

    # Start watchers
    threads = []
    threads.append(threading.Thread(target=watch_resource,
                    args=('POD', v1.list_namespaced_pod, args.namespace, rv_p, args.output_file, lock)))
    threads.append(threading.Thread(target=watch_resource,
                    args=('SVC', v1.list_namespaced_service, args.namespace, rv_svc, args.output_file, lock)))
    threads.append(threading.Thread(target=watch_resource,
                    args=('SA', v1.list_namespaced_service_account, args.namespace, rv_sa, args.output_file, lock)))
    for t in threads:
        t.daemon = True
        t.start()

    # Keep main alive
    for t in threads:
        t.join()

if __name__ == '__main__':
    main()