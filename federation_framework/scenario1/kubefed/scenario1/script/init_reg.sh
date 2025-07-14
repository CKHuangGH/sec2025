#!/bin/bash

kubectl config use-context cluster0

for i in $(cat node_exec)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

helm --namespace kube-federation-system upgrade -i kubefed kubefed-charts/kubefed --version 0.9.2 --create-namespace
sleep 10

cluster=1
for i in $(cat node_exec)
do
	kubefedctl join cluster$cluster --cluster-context cluster$cluster --host-cluster-context cluster0 --v=2
    cluster=$((cluster+1))
done