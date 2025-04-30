#!/bin/bash

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

# 設定基底名字
BASE_NAME="kube-prometheus-stack"
OUTPUT_FILE="patched-clusterrole.yaml"

# 自動找出符合的 ClusterRole 名稱（只取 metadata.name）
CLUSTERROLE_NAME=$(kubectl get clusterrole -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "${BASE_NAME}-.*-prometheus" | head -n1)

if [ -z "$CLUSTERROLE_NAME" ]; then
  echo "❌ 找不到符合 ${BASE_NAME}-*-prometheus 格式的 ClusterRole！"
  exit 1
fi

echo "🔎 找到 ClusterRole: ${CLUSTERROLE_NAME}"

# 匯出原本的 ClusterRole
kubectl get clusterrole ${CLUSTERROLE_NAME} -o yaml > original-clusterrole.yaml

# 檢查是否成功
if [ $? -ne 0 ]; then
  echo "❌ 匯出 ClusterRole 失敗！"
  exit 1
fi

# 用 awk 插入新的 rule
awk '
/^rules:/ {print; in_rules=1; next}
in_rules && /^[^ ]/ {
    print "- apiGroups:\n  - cluster.karmada.io\n  resources:\n  - \"*\"\n  verbs:\n  - \"*\""
    in_rules=0
}
{print}
END {
    if (in_rules) {
        print "- apiGroups:\n  - cluster.karmada.io\n  resources:\n  - \"*\"\n  verbs:\n  - \"*\""
    }
}
' original-clusterrole.yaml > ${OUTPUT_FILE}

echo "✅ 已經把修改後的 ClusterRole 存到 ${OUTPUT_FILE}"

# 線上直接 patch 原本的 ClusterRole
echo "🚀 開始線上 patch ClusterRole..."

kubectl patch clusterrole ${CLUSTERROLE_NAME} --type='json' -p='[
  {
    "op": "add",
    "path": "/rules/-",
    "value": {
      "apiGroups": ["cluster.karmada.io"],
      "resources": ["*"],
      "verbs": ["*"]
    }
  }
]'

if [ $? -eq 0 ]; then
  echo "✅ 線上 patch 成功！"
else
  echo "❌ 線上 patch 失敗，請手動檢查。"
fi

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

kubectl apply -f secret.yaml --kubeconfig /etc/karmada/karmada-apiserver.config

# 設定變數
KUBECONFIG_PATH="/etc/karmada/karmada-apiserver.config"
SECRET_NAME="prometheus"
NAMESPACE="monitoring"
VALUES_FILE="/root/sec2025/federation_framework/scenario1/karmada-pull/values.yaml"
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


# 找出 release name（以 kube-prometheus-stack 開頭）
RELEASE_NAME=$(helm list -n monitoring -o json | jq -r '.[] | select(.name | startswith("kube-prometheus-stack")) | .name')

# 檢查是否找到 release
if [ -z "$RELEASE_NAME" ]; then
  echo "找不到 kube-prometheus-stack 的 Helm Release"
  exit 1
fi

echo "找到的 Release: $RELEASE_NAME"

# 執行 helm upgrade
helm upgrade "$RELEASE_NAME" prometheus-community/kube-prometheus-stack \
  --version 70.4.2 \
  --namespace monitoring \
  --values /root/sec2025/federation_framework/scenario1/karmada-pull/values.yaml \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.service.type=NodePort \
  --set prometheus.prometheusSpec.scrapeInterval="5s" \
  --set prometheus.prometheusSpec.enableAdminAPI=true \
  --set prometheus.prometheusSpec.resources.requests.cpu="250m" \
  --set prometheus.prometheusSpec.resources.requests.memory="512Mi"