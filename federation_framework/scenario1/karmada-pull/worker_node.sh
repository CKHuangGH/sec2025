#!/bin/bash
cluster=$1

kubectl config use-context cluster$cluster
helm repo update
helm install cilium cilium/cilium --version 1.17.2 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
sleep 30
kubectl create ns monitoring
    helm install --version 70.4.2 prometheus-community/kube-prometheus-stack --generate-name --set grafana.enabled=false --set alertmanager.enabled=false --set prometheus.service.type=NodePort --set prometheus.prometheusSpec.scrapeInterval="5s" --namespace monitoring
sleep 30

# echo "Install Metrics server-----------------------"
# kubectl --context=cluster$cluster create -f metrics_server.yaml
# ./patch.sh
# echo "-----------------------Member cluster$cluster is ready----------------------"