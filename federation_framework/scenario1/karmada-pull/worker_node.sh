#!/bin/bash
cluster=$1

mkdir /var/log/ntpsec
pip3 install kubernetes --break-system-packages

sed -i 's|--listen-metrics-urls=http://127.0.0.1:2381|--listen-metrics-urls=http://0.0.0.0:2381|' "/etc/kubernetes/manifests/etcd.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-scheduler.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-controller-manager.yaml"
sleep 30

kubectl config use-context cluster$cluster
helm repo update
helm install cilium cilium/cilium --version 1.17.2 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
sleep 30