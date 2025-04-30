#!/bin/bash

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