#!/bin/bash

kubectl config use-context cluster0

for i in $(cat node_exec)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

kubectl create namespace liqo
helm install liqo liqo/liqo --namespace liqo --version v1.0.1 --create-namespace
# liqoctl install kubeadm --pod-cidr 10.0.0.0/8 --service-cidr 10.0.0.0/8 --version v1.0.1
# liqoctl install kubeadm --version v1.0.1
sleep 10

cluster=1
for i in $(cat node_exec)
do
    liqoctl peer --kubeconfig $HOME/.kube/cluster0 --remote-kubeconfig $HOME/.kube/cluster$cluster
	cluster=$((cluster+1))
done

liqoctl info
liqoctl info peer
sleep 10