#!/bin/bash

set -e

# 導出 monitoring namespace 的 YAML
kubectl get namespace monitoring -o yaml > monitoring-namespace.yaml
echo "✅ 已導出 monitoring namespace 至 monitoring-namespace.yaml"

# 找出符合 kube-prometheus-stack-*-prometheus 的 ServiceAccount 名稱
SA_NAME=$(kubectl get sa -n monitoring --no-headers -o custom-columns=":metadata.name" | grep '^kube-prometheus-stack-.*-prometheus$')

if [ -z "$SA_NAME" ]; then
  echo "❌ 找不到符合條件的 ServiceAccount"
  exit 1
fi

# 導出 ServiceAccount 的 YAML
kubectl get sa "$SA_NAME" -n monitoring -o yaml > "sa.yaml"
echo "✅ 已導出 ServiceAccount $SA_NAME 至 sa.yaml"

# 找出符合的 ClusterRoleBinding 名稱
CRB_NAME=$(kubectl get clusterrolebinding --no-headers -o custom-columns=":metadata.name" | grep "^${SA_NAME}$")

if [ -z "$CRB_NAME" ]; then
  echo "❌ 找不到符合條件的 ClusterRoleBinding"
  exit 1
fi

# 導出 ClusterRoleBinding 的 YAML
kubectl get clusterrolebinding "$CRB_NAME" -o yaml > "crb.yaml"
echo "✅ 已導出 ClusterRoleBinding $CRB_NAME 至 crb.yaml"

echo "🎉 全部資源導出完成！"