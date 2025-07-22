#!/bin/bash
cluster=$1

mkdir /var/log/ntpsec
pip3 install kubernetes --break-system-packages

curl --fail -LS "https://github.com/liqotech/liqo/releases/download/v1.0.1/liqoctl-linux-amd64.tar.gz" | tar -xz
sudo install -o root -g root -m 0755 liqoctl /usr/local/bin/liqoctl

sed -i 's|--listen-metrics-urls=http://127.0.0.1:2381|--listen-metrics-urls=http://0.0.0.0:2381|' "/etc/kubernetes/manifests/etcd.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-scheduler.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-controller-manager.yaml"
sleep 60

kubectl config use-context cluster$cluster
helm repo update
helm install cilium cilium/cilium --version 1.17.2 --namespace kube-system --wait --wait-for-jobs -f /root/sec2025/federation_framework/scenario1/liqo/cilium-values.yaml
sleep 30