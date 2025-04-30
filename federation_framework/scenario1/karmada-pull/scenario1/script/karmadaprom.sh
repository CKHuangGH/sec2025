#!/bin/bash
kubectl apply -f monitoring-namespace.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f sa.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f crb.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f patched-clusterrole.yaml --kubeconfig /etc/karmada/karmada-apiserver.config

# 檔案路徑
CLUSTERROLE_FILE="patched-clusterrole.yaml"
SECRET_FILE="secret.yaml"
TEMP_FILE="secret.tmp.yaml"

# 取得 ClusterRole 的 metadata.name
SERVICE_ACCOUNT_NAME=$(grep '^[[:space:]]*name:' "$CLUSTERROLE_FILE" | head -n 1 | awk '{print $2}')

# 確保有抓到 name
if [[ -z "$SERVICE_ACCOUNT_NAME" ]]; then
  echo "找不到 ClusterRole 的 metadata.name"
  exit 1
fi

# 替換 secret.yaml 中的 service-account.name 註解
# 使用 awk 進行行為級處理
awk -v newname="$SERVICE_ACCOUNT_NAME" '
  BEGIN { changed = 0 }
  {
    if ($0 ~ /kubernetes.io\/service-account.name:/) {
      print "    kubernetes.io/service-account.name: \"" newname "\""
      changed = 1
    } else {
      print $0
    }
  }
  END {
    if (!changed) {
      print "未找到 kubernetes.io/service-account.name 欄位，請確認格式"
      exit 1
    }
  }
' "$SECRET_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SECRET_FILE"

echo "已更新 secret.yaml 中的 service-account.name 為：$SERVICE_ACCOUNT_NAME"

#!/bin/bash

# 設定變數
KUBECONFIG_PATH="/etc/karmada/karmada-apiserver.config"
SECRET_NAME="prometheus"
NAMESPACE="monitoring"
VALUES_FILE="values.yaml"
PLACEHOLDER="changehere"

# 取得 token 並解碼
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
  -o=jsonpath="{.data.token}" --kubeconfig "$KUBECONFIG_PATH" | base64 -d)

# 檢查 token 是否成功取得
if [[ -z "$TOKEN" ]]; then
  echo "❌ 無法取得或解碼 token，請確認 secret 是否存在。"
  exit 1
fi

# 使用 sed 替換 values.yaml 中的 changehere 為 token
# 注意處理 token 中可能包含的 `/` 或 `&` 等特殊字元
ESCAPED_TOKEN=$(printf '%s\n' "$TOKEN" | sed -e 's/[\/&]/\\&/g')
sed -i "s/$PLACEHOLDER/$ESCAPED_TOKEN/" "$VALUES_FILE"

echo "✅ 已成功將 token 寫入 $VALUES_FILE"

helm upgrade kube-prometheus-stack-1745962256 prometheus-community/kube-prometheus-stack   --version 70.4.2   --namespace monitoring   --values values.yaml   --set grafana.enabled=false   --set alertmanager.enabled=false   --set prometheus.service.type=NodePort   --set prometheus.prometheusSpec.scrapeInterval="5s"   --set prometheus.prometheusSpec.enableAdminAPI=true   --set prometheus.prometheusSpec.resources.requests.cpu="250m"   --set prometheus.prometheusSpec.resources.requests.memory="512Mi"