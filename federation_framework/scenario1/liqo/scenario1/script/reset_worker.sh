#!/bin/bash

number=$1

# kubectl delete secret karmada-kubeconfig -n karmada-system

# kubectl delete sa karmada-agent-sa -n karmada-system

# kubectl delete deployment karmada-agent -n karmada-system

# kubectl delete ns karmada-cluster

# kubectl delete ns karmada-system

liqoctl uninstall --skip-confirm --purge

kubectl delete namespace liqo-demo

kubectl delete ns liqo

kubectl delete ns monitoring

rm -f /root/time.txt

rm -f /root/number.txt

rm -f /root/resource_all.csv

rm -f /root/resource_avg_10min.csv

rm -f /root/apiserver_metrics_avg_10min.csv

rm -f /root/controller_extended_metrics.csv

rm -f /root/snapshot.json

# rm -f /etc/karmada/karmada-agent.conf

# rm -f /etc/karmada/pki/ca.crt

rm -rf /root/prom-$number/

while true; do
    running_pods=$(kubectl get pod -n liqo --no-headers | wc -l)
    echo "liqo pod: $running_pods"
    if [ "$running_pods" -eq 0 ]; then
        break
    else
        sleep 1
    fi
done