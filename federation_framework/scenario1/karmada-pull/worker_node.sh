#!/bin/bash
cluster=$1

sudo systemctl stop ntp
sudo ntpd -gq
sudo systemctl start ntp
pip3 install kubernetes --break-system-packages

kubectl config use-context cluster$cluster
helm repo update
helm install cilium cilium/cilium --version 1.17.2 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
sleep 30
kubectl create ns monitoring
helm install --version 70.4.2 prometheus-community/kube-prometheus-stack --generate-name --set grafana.enabled=false --set alertmanager.enabled=false --set prometheus.service.type=NodePort --set prometheus.prometheusSpec.scrapeInterval="5s" --set prometheus.prometheusSpec.enableAdminAPI=true --namespace monitoring
sleep 30