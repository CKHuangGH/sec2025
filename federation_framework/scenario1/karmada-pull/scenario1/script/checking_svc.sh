#!/bin/bash

numberofsvc=$1
SLEEP_INTERVAL=1

while true; do
    running_pods=$(kubectl get svc --no-headers --context cluster1 | wc -l)
    echo "pods: "$running_pods
    if [ "$running_pods" -eq "$numberofsvc" ]; then
        current_time=$(date +'%s.%N')
        echo timeforsvc $current_time >> time.txt
        break
    else
        sleep $SLEEP_INTERVAL
    fi
done