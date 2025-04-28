#!/bin/bash

expected_pods=$1
expected_services=$2
expected_sa=$3

CONTEXT="cluster1"
NAMESPACE="default"

pod_ready=0
svc_ready=0
sa_ready=0

time_pod=""
time_svc=""
time_sa=""

lockfile="/tmp/watch_lock_$$"
touch $lockfile

log_status() {
    local resource=$1
    local current=$2
    local expected=$3
    local timestamp=$(date +'%s.%N')
    echo "$timestamp $resource $current / $expected" >> time.txt
}

check_pod() {
    pod_count=$(kubectl get pods --context $CONTEXT -n $NAMESPACE \
        -o json | jq '[.items[] | select(.status.phase=="Running") | select(all(.status.containerStatuses[]?; .ready==true))] | length')

    if [ "$pod_count" -ne "$last_pod_count" ]; then
        log_status "pods" "$pod_count" "$expected_pods"
        last_pod_count=$pod_count
    fi
    if [ "$pod_count" -eq "$expected_pods" ] && [ "$pod_ready" -eq 0 ]; then
        time_pod=$(date +'%s.%N')
        echo "✅ Pods ready at $time_pod"
        echo "timeforpods $time_pod" >> time.txt
        pod_ready=1
    fi
}

check_svc() {
    svc_count=$(kubectl get svc --no-headers --context $CONTEXT -n $NAMESPACE | wc -l)
    log_status "services" "$svc_count" "$expected_services"
    if [ "$svc_count" -eq "$expected_services" ] && [ "$svc_ready" -eq 0 ]; then
        time_svc=$(date +'%s.%N')
        echo "✅ Services ready at $time_svc"
        echo "timeforsvc $time_svc" >> time.txt
        svc_ready=1
    fi
}

check_sa() {
    sa_count=$(kubectl get sa --no-headers --context $CONTEXT -n $NAMESPACE | wc -l)
    log_status "serviceaccounts" "$sa_count" "$expected_sa"
    if [ "$sa_count" -eq "$expected_sa" ] && [ "$sa_ready" -eq 0 ]; then
        time_sa=$(date +'%s.%N')
        echo "✅ ServiceAccounts ready at $time_sa"
        echo "timeforsa $time_sa" >> time.txt
        sa_ready=1
    fi
}

check_all_ready() {
    if [ "$pod_ready" -eq 1 ] && [ "$svc_ready" -eq 1 ] && [ "$sa_ready" -eq 1 ]; then
        echo "🎉 All resources ready!"
        echo "All ready! Pods at $time_pod, SVC at $time_svc, SA at $time_sa" >> time.txt
        rm -f $lockfile
        kill 0
    fi
}

# Initial check before watch (防止一開始就 ready 沒有 event)
check_pod
check_svc
check_sa
check_all_ready

# Pod watcher
kubectl get pods --watch --context $CONTEXT -n $NAMESPACE | while read line; do
    if [ ! -f $lockfile ]; then break; fi
    check_pod
    check_all_ready
done &

# Service watcher
kubectl get svc --watch --context $CONTEXT -n $NAMESPACE | while read line; do
    if [ ! -f $lockfile ]; then break; fi
    check_svc
    check_all_ready
done &

# ServiceAccount watcher
kubectl get sa --watch --context $CONTEXT -n $NAMESPACE | while read line; do
    if [ ! -f $lockfile ]; then break; fi
    check_sa
    check_all_ready
done &

# Wait for all background processes
wait