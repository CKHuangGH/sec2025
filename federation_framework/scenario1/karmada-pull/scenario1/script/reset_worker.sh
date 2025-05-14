#!/bin/bash

rm -f /root/time.txt

rm -f /root/number.txt

rm -f /root/resource_all.csv

rm -f /root/resource_avg_10min.csv

rm -f /root/apiserver_metrics_avg_10min.csv

rm -f /root/controller_extended_metrics.csv

rm -f /etc/karmada/karmada-agent.conf

rm -f /etc/karmada/pki/ca.crt

while true; do
    running_pods=$(kubectl get pod -n karmada-system --no-headers | wc -l)
    echo "Karmada member pod: $running_pods"
    if [ "$running_pods" -eq 0 ]; then
        break
    else
        sleep 1
    fi
done