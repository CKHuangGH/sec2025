#!/bin/bash
set -euo pipefail

# === [CONFIGURATION] ===
# 要加入聯邦的叢集 (Member/Joining Cluster)
JOIN_CLUSTER_CONTEXT="cluster1"
# KubeFed 控制平面所在的叢集 (Host Cluster)
HOST_CLUSTER_CONTEXT="cluster0"
# KubeFed 使用的命名空間
FED_NAMESPACE="kube-federation-system"
# ServiceAccount 的名稱 (基於叢集名稱自動產生)
SA_NAME="${JOIN_CLUSTER_CONTEXT}-${HOST_CLUSTER_CONTEXT}"
# 手動建立的包含 token 的 secret 名稱
SECRET_NAME="${SA_NAME}-token"

echo "📌 HOST: ${HOST_CLUSTER_CONTEXT}"
echo "📌 JOIN: ${JOIN_CLUSTER_CONTEXT}"
echo "📌 NAMESPACE: ${FED_NAMESPACE}"
echo "📌 ServiceAccount: ${SA_NAME}"
echo "📌 Secret: ${SECRET_NAME}"

# ---

# === (OPTIONAL) Untaint control-plane nodes ===
# 這部分是可選的，取決於你的叢集設定。
# 如果 KubeFed Pods 因為 Taints 無法調度，可以啟用這段
if [[ -f "node_exec" ]]; then
  echo "🔧 Untainting control-plane nodes..."
  for i in $(<node_exec); do
    ssh root@"$i" kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- || true
  done
fi

# ---

# === Step 1: Install/Upgrade KubeFed on HOST cluster ===
echo "📦 Installing kubefed via Helm in host cluster..."
helm repo add kubefed-charts https://raw.githubusercontent.com/kubernetes-sigs/kubefed/master/charts --force-update >/dev/null 2>&1
helm repo update
helm upgrade -i kubefed kubefed-charts/kubefed \
  --version 0.10.0 \
  --namespace "${FED_NAMESPACE}" \
  --create-namespace \
  --kube-context "${HOST_CLUSTER_CONTEXT}"
# 等待 KubeFed Pods 穩定
echo "⏳ Waiting for KubeFed Helm deployment to stabilize..."
sleep 15

# ---

# === Step 2: Ensure namespace exists in both clusters ===
echo "📁 Ensuring federation namespace exists in both clusters..."
for CTX in "${JOIN_CLUSTER_CONTEXT}" "${HOST_CLUSTER_CONTEXT}"; do
  kubectl get ns "${FED_NAMESPACE}" --context="${CTX}" >/dev/null 2>&1 \
    || kubectl create ns "${FED_NAMESPACE}" --context="${CTX}"
done

# ---

# === Step 3: Create ServiceAccount in both clusters ===
echo "👤 Creating ServiceAccount in both clusters..."
for CTX in "${JOIN_CLUSTER_CONTEXT}" "${HOST_CLUSTER_CONTEXT}"; do
  kubectl get sa "${SA_NAME}" -n "${FED_NAMESPACE}" --context="${CTX}" >/dev/null 2>&1 \
    || kubectl create sa "${SA_NAME}" -n "${FED_NAMESPACE}" --context="${CTX}"
done

# ---

# === Step 4: Generate token via TokenRequest API on JOIN cluster ===
echo "🔐 Creating token via TokenRequest API in ${JOIN_CLUSTER_CONTEXT}..."
TOKEN=$(kubectl create token "${SA_NAME}" -n "${FED_NAMESPACE}" --context="${JOIN_CLUSTER_CONTEXT}")
if [[ -z "${TOKEN}" ]]; then
  echo "❌ Failed to retrieve token. Check ServiceAccount in ${JOIN_CLUSTER_CONTEXT}."
  exit 1
fi
echo "✅ Token retrieved for ServiceAccount: ${SA_NAME}."

# ---

# === Step 5: Extract CA cert and encode namespace ===
echo "📡 Extracting CA cert from kubeconfig for ${JOIN_CLUSTER_CONTEXT}..."
CA_CRT=$(kubectl config view --raw --context="${JOIN_CLUSTER_CONTEXT}" \
  -o jsonpath="{.clusters[?(@.name == \"${JOIN_CLUSTER_CONTEXT}\")].cluster.certificate-authority-data}")
# Encode namespace to base64
NS_B64=$(echo -n "${FED_NAMESPACE}" | base64)

# ---

# === Step 6: Create Opaque Secret in JOIN cluster containing token, ca.crt, namespace ===
# 雖然 'kubefedctl join' 在此場景下會失敗，但建立這個 Secret 仍然是個好習慣，
# 並且我們的腳本邏輯依賴它來驗證 token 是否已成功產生。
echo "🛠 Creating join-cluster Secret (Opaque) '${SECRET_NAME}' in ${JOIN_CLUSTER_CONTEXT}..."
kubectl apply --context="${JOIN_CLUSTER_CONTEXT}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${FED_NAMESPACE}
type: Opaque
data:
  token:     $(echo -n "${TOKEN}" | base64 | tr -d '\n')
  ca.crt:    ${CA_CRT}
  namespace: ${NS_B64}
EOF

# ---

# === Step 6.1: Wait for the Secret to be fully ready and propagated ===
echo "⏳ Waiting for Secret '${SECRET_NAME}' to be ready and populated in ${JOIN_CLUSTER_CONTEXT} (max 60 seconds)..."
SECRET_READY=false
for i in {1..30}; do # Check every 2 seconds for up to 60 seconds
  if kubectl get secret "${SECRET_NAME}" -n "${FED_NAMESPACE}" \
      --context="${JOIN_CLUSTER_CONTEXT}" \
      -o jsonpath='{.data.token}' 2>/dev/null | grep -q .; then
    echo "✅ Secret is populated and ready."
    SECRET_READY=true
    break
  fi
  sleep 2
done

if ! $SECRET_READY; then
  echo "❌ Error: Secret '${SECRET_NAME}' in namespace '${FED_NAMESPACE}' on cluster '${JOIN_CLUSTER_CONTEXT}' did not become populated with a token in time."
  echo "Please check the status of the secret and the Kubernetes API server in ${JOIN_CLUSTER_CONTEXT}."
  exit 1
fi

# ---

# === (DEPRECATED) Step 7: The command below fails on K8s v1.24+ ===
# `kubefedctl join` has an outdated mechanism that waits for an auto-generated
# SA token secret, which is no longer created by default in K8s 1.24+.
# We will perform its actions manually below.
#
# echo "🚀 Running kubefedctl join command for ${JOIN_CLUSTER_CONTEXT}..."
# kubefedctl join "${JOIN_CLUSTER_CONTEXT}" \
#   --host-cluster-context="${HOST_CLUSTER_CONTEXT}" \
#   --cluster-context="${JOIN_CLUSTER_CONTEXT}" \
#   --secret-name="${SECRET_NAME}" \
#   --error-on-existing=false \
#   --v=2
# ---

# === (NEW) Step 7: Manually create KubeFedCluster resources in the Host Cluster ===
echo "⚙️  Manually creating KubeFed resources in host cluster (${HOST_CLUSTER_CONTEXT})..."

# 7.1: Get the API Server Endpoint of the joining cluster
API_ENDPOINT=$(kubectl config view --raw --context="${JOIN_CLUSTER_CONTEXT}" \
  -o jsonpath="{.clusters[?(@.name == \"${JOIN_CLUSTER_CONTEXT}\")].cluster.server}")

if [[ -z "${API_ENDPOINT}" ]]; then
    echo "❌ Failed to retrieve API endpoint for cluster ${JOIN_CLUSTER_CONTEXT}."
    exit 1
fi
echo "✅ API Endpoint for ${JOIN_CLUSTER_CONTEXT} is ${API_ENDPOINT}"

# 7.2: Create the KubeFed secret in the Host Cluster (cluster0)
# The secret name must match the name of the joining cluster.
echo "🛠 Creating KubeFed secret '${JOIN_CLUSTER_CONTEXT}' in host cluster..."
kubectl apply --context="${HOST_CLUSTER_CONTEXT}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${JOIN_CLUSTER_CONTEXT}
  namespace: ${FED_NAMESPACE}
type: Opaque
data:
  token: $(echo -n "${TOKEN}" | base64 | tr -d '\n')
  ca.crt: ${CA_CRT}
EOF

# 7.3: Create the KubeFedCluster object in the Host Cluster (cluster0)
echo "📝 Creating KubeFedCluster object for '${JOIN_CLUSTER_CONTEXT}' in host cluster..."
kubectl apply --context="${HOST_CLUSTER_CONTEXT}" -f - <<EOF
apiVersion: core.kubefed.io/v1beta1
kind: KubeFedCluster
metadata:
  name: ${JOIN_CLUSTER_CONTEXT}
  namespace: ${FED_NAMESPACE}
spec:
  apiEndpoint: ${API_ENDPOINT}
  caBundle: ${CA_CRT}
  secretRef:
    name: ${JOIN_CLUSTER_CONTEXT}
EOF

# ---

echo "🎉 SUCCESS: ${JOIN_CLUSTER_CONTEXT} has been successfully and manually joined to the federation!"