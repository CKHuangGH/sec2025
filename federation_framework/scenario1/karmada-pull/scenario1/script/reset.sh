#!/bin/bash

echo "Searching for and terminating tcpdump-related processes..."
PIDS=$(pgrep -f "tcpdump")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All tcpdump processes have been terminated."
else
    echo "No tcpdump processes found."
fi

kubectl karmada unregister cluster1 --cluster-kubeconfig /root/.kube/cluster1

echo "y" | kubectl karmada deinit

rm -rf /var/lib/karmada-etcd

rm -f ../number.txt

rm -f ../cross

rm -f /root/resource_all.csv

rm -f /root/resource_avg_10min.csv