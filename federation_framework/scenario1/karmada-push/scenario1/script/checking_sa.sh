#!/bin/bash

numberofsa=$1
SLEEP_INTERVAL=1

while true; do
    running_pods=$(kubectl get sa --no-headers --context cluster1 | wc -l)
    echo "sa: "$running_pods
    if [ "$running_pods" -eq "$numberofsa" ]; then
        current_time=$(date +'%s.%N')
        echo timeforsa $current_time >> time.txt
        break
    else
        sleep $SLEEP_INTERVAL
    fi
done