#!/bin/bash

echo "Searching for and terminating bash-related processes..."
PIDS=$(pgrep -f "toppodwa")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All bash processes have been terminated."
else
    echo "No bash processes found."
fi

rm -f kubetopPodWA.csv

clusteradm unjoin --cluster-name cluster1