#!/bin/bash

numberofpod=$1
SLEEP_INTERVAL=1

while true; do
    running_pods=$(kubectl get pods -n liqo-demo --field-selector=status.phase=Running --no-headers --context cluster1 | wc -l)
    echo "pods: "$running_pods
    if [ "$running_pods" -eq "$numberofpod" ]; then
        current_time=$(date +'%s.%N')
        echo timeforpods $current_time >> time.txt
        break
    else
        sleep $SLEEP_INTERVAL
    fi
done