#!/bin/bash

expected_pods=$1
expected_services=$2
expected_sa=$3

CONTEXT="cluster1"
NAMESPACE="default"

all_ready=false

timestamp() {
    date +'%s.%N'
}

log_status() {
    local resource=$1
    local current=$2
    local expected=$3
    echo "$(timestamp) $resource $current / $expected" >> time.txt
}

check_all_ready() {
    local current_pods=$(kubectl get pods --context "$CONTEXT" -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.phase=="Running" && .status.containerStatuses[*].ready==true)].metadata.name}' | wc -w)
    local current_svcs=$(kubectl get svc --no-headers --context "$CONTEXT" -n "$NAMESPACE" | wc -l)
    local current_sas=$(kubectl get sa --no-headers --context "$CONTEXT" -n "$NAMESPACE" | wc -l)

    log_status "pods" "$current_pods" "$expected_pods"
    log_status "services" "$current_svcs" "$expected_services"
    log_status "serviceaccounts" "$current_sas" "$expected_sa"

    if [ "$current_pods" -eq "$expected_pods" ] &&
       [ "$current_svcs" -eq "$expected_services" ] &&
       [ "$current_sas" -eq "$expected_sa" ]; then
        if ! "$all_ready"; then
            echo "🎉 All resources ready!"
            echo "timeforpods $(timestamp)" >> time.txt
            echo "timeforsvc $(timestamp)" >> time.txt
            echo "timeforsa $(timestamp)" >> time.txt
            all_ready=true
        fi
        return 0
    else
        return 1
    fi
}

# 監控資源
watch_resources() {
    kubectl get pods,svc,sa --watch --context "$CONTEXT" -n "$NAMESPACE" |
    while read -r event; do
        check_all_ready
        if "$all_ready"; then
            return 0
        fi
    done
}

# 初始檢查
check_all_ready
if "$all_ready"; then
    exit 0
fi

# 開始監控
watch_resources

echo "⚠️ Monitoring finished without all resources becoming ready." >&2
exit 1