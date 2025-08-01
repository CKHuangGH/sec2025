#!/bin/bash

number=$1

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

sleep 10

echo "y" | kubectl karmada deinit

rm -rf /root/prom-$number/

rm -rf /root/prom-$number-member/

rm -rf /var/lib/karmada-etcd

rm -f /root/number.txt

rm -f ../number.txt

rm -rf ../snapshot.json

rm -f ../cross

kubectl delete ns monitoring

while true; do
    running_pods=$(kubectl get pod -n karmada-system --no-headers | wc -l)
    echo "Karmada CP pod: $running_pods"
    if [ "$running_pods" -eq 0 ]; then
        break
    else
        sleep 1
    fi
done