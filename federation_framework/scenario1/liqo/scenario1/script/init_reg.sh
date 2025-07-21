#!/bin/bash

kubectl config use-context cluster0

for i in $(cat node_exec)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

kubectl create namespace liqo
liqoctl install --pod-cidr 10.0.0.0/16 --service-cidr 10.96.0.0/12 --version v1.0.1 --cluster-id cluster0 --context cluster0
liqoctl install --pod-cidr 10.0.0.0/16 --service-cidr 10.96.0.0/12 --version v1.0.1 --cluster-id cluster1 --context cluster1
sleep 10

cluster=1
for i in $(cat node_exec)
do
    liqoctl peer --remote-kubeconfig $HOME/.kube/cluster$cluster --gw-server-service-type NodePort
	cluster=$((cluster+1))
done
kubectl create namespace default
liqoctl offload namespace default --namespace-mapping-strategy EnforceSameName --pod-offloading-strategy Remote