#!/usr/bin/env python3

import argparse
import signal
import sys
import threading
import os
import csv
from datetime import datetime

from kubernetes import client, config, watch

# Global state
counts = {}
thresholds = {}
thresholds_reached = {}
pod_phases = {}

def record_event(resource_name, event_type, count, output_file, lock):
    """
    Print and (only for THRESHOLD_REACHED) append to CSV.
    """
    ts = int(datetime.utcnow().timestamp())
    print(f"{resource_name} {event_type} count={count} ts={ts}")

    if event_type == 'THRESHOLD_REACHED' and output_file:
        with lock:
            header = not os.path.exists(output_file) or os.path.getsize(output_file) == 0
            with open(output_file, 'a', newline='') as f:
                writer = csv.writer(f)
                if header:
                    writer.writerow(['resource','event','count','timestamp'])
                writer.writerow([resource_name, event_type, count, ts])

    return True  # 一旦寫入，就視為已觸發

def watch_resource(name, list_fn, namespace, rv, out_file, lock, stop_evt):
    w = watch.Watch()
    try:
        for ev in w.stream(list_fn, namespace=namespace, resource_version=rv):
            if stop_evt.is_set(): break

            typ = ev['type']
            cnt = counts[name]
            if typ == 'ADDED':
                cnt += 1
            elif typ == 'DELETED':
                cnt -= 1
            else:
                continue

            counts[name] = cnt

            if not thresholds_reached[name] and cnt <= thresholds[name]:
                thresholds_reached[name] = record_event(name, 'THRESHOLD_REACHED', cnt, out_file, lock)
                if all(thresholds_reached.values()):
                    stop_evt.set()
                    break

    except Exception as e:
        with lock:
            print(f"Error watching {name}: {e}")
    finally:
        w.stop()

def watch_pods(namespace, api, rv, out_file, lock, stop_evt):
    w = watch.Watch()
    run_cnt = counts['POD']
    try:
        for ev in w.stream(api.list_namespaced_pod, namespace=namespace, resource_version=rv):
            if stop_evt.is_set(): break

            pod = ev['object']
            uid = pod.metadata.uid
            new_ph = pod.status.phase
            old_ph = pod_phases.get(uid)
            typ = ev['type']

            if typ == 'ADDED':
                pod_phases[uid] = new_ph
                if new_ph == 'Running':
                    run_cnt += 1
            elif typ == 'DELETED':
                if old_ph == 'Running':
                    run_cnt -= 1
                pod_phases.pop(uid, None)
            elif typ == 'MODIFIED':
                if old_ph != 'Running' and new_ph == 'Running':
                    run_cnt += 1
                elif old_ph == 'Running' and new_ph != 'Running':
                    run_cnt -= 1
                pod_phases[uid] = new_ph
            else:
                continue

            counts['POD'] = run_cnt

            if not thresholds_reached['POD'] and run_cnt <= thresholds['POD']:
                thresholds_reached['POD'] = record_event('POD', 'THRESHOLD_REACHED', run_cnt, out_file, lock)
                if all(thresholds_reached.values()):
                    stop_evt.set()
                    break

    except Exception as e:
        with lock:
            print(f"Error watching PODs: {e}")
    finally:
        w.stop()

def main():
    p = argparse.ArgumentParser(
        description='Monitor running pods, services, serviceaccounts; record when count drops to threshold'
    )
    p.add_argument('-n','--namespace', default='default')
    p.add_argument('--pod-threshold', type=int, required=True, help='Running-pod count threshold')
    p.add_argument('--svc-threshold', type=int, required=True, help='Service count threshold')
    p.add_argument('--sa-threshold', type=int, required=True, help='ServiceAccount count threshold')
    p.add_argument('-o','--output-file', default='/root/timestamp.csv')
    args = p.parse_args()

    # 讀 kubeconfig
    try:
        config.load_incluster_config()
    except:
        config.load_kube_config()

    v1 = client.CoreV1Api()
    lock = threading.Lock()
    stop_evt = threading.Event()

    # signal handler
    def _sig(signum, frame):
        print(f"Got signal {signum}, stopping")
        stop_evt.set()
    signal.signal(signal.SIGINT,  _sig)
    signal.signal(signal.SIGTERM, _sig)

    global counts, thresholds, thresholds_reached, pod_phases
    thresholds = {
        'POD': args.pod_threshold,
        'SVC': args.svc_threshold,
        'SA' : args.sa_threshold,
    }
    thresholds_reached = {k: False for k in thresholds}

    # 初始狀態
    pods = v1.list_namespaced_pod(namespace=args.namespace)
    for pod in pods.items:
        pod_phases[pod.metadata.uid] = pod.status.phase
    run0 = sum(1 for ph in pod_phases.values() if ph == 'Running')
    counts['POD'] = run0
    rv_p = pods.metadata.resource_version

    svcs = v1.list_namespaced_service(namespace=args.namespace)
    counts['SVC'] = len(svcs.items)
    rv_s = svcs.metadata.resource_version

    sas = v1.list_namespaced_service_account(namespace=args.namespace)
    counts['SA'] = len(sas.items)
    rv_sa = sas.metadata.resource_version

    # 初次檢查
    if run0 <= thresholds['POD']:
        thresholds_reached['POD'] = record_event('POD','THRESHOLD_REACHED',run0,args.output_file,lock)
    if counts['SVC'] <= thresholds['SVC']:
        thresholds
