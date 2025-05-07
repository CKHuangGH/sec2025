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

kubectl create ns monitoring
helm install --version 70.4.2 prometheus-community/kube-prometheus-stack --generate-name --set grafana.enabled=false --set alertmanager.enabled=false --set prometheus.service.type=NodePort --set prometheus.prometheusSpec.scrapeInterval="5s" --set prometheus.prometheusSpec.enableAdminAPI=true --namespace monitoring --values /root/sec2025/federation_framework/scenario1/karmada-pull/values_worker.yaml --set prometheus.prometheusSpec.resources.requests.cpu="250m" --set prometheus.prometheusSpec.resources.requests.memory="512Mi"
sleep 30