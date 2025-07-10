#!/bin/bash

number=$1

kubectl delete ns monitoring

rm -f /root/time.txt

rm -f /root/number.txt

rm -f /root/resource_all.csv

rm -f /root/resource_avg_10min.csv

rm -f /root/apiserver_metrics_avg_10min.csv

rm -f /root/controller_extended_metrics.csv

rm -rf /root/prom-$number/

rm -f /root/snapshot.json

clusteradm unjoin --cluster-name cluster1