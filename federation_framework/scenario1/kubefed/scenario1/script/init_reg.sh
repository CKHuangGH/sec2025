#!/bin/bash

kubectl config use-context cluster0

for i in $(cat node_exec)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

helm --namespace kube-federation-system upgrade -i kubefed kubefed-charts/kubefed --version 0.9.2 --create-namespace
sleep 10

# === User-defined parameters ===
JOIN_CLUSTER_CONTEXT="cluster1"
HOST_CLUSTER_CONTEXT="cluster0"
FED_NAMESPACE="kube-federation-system"
SA_NAME="${JOIN_CLUSTER_CONTEXT}-${HOST_CLUSTER_CONTEXT}"
SECRET_NAME="${SA_NAME}-token"

# === Step 1: Ensure namespace exists ===
kubectl get ns ${FED_NAMESPACE} --context=${JOIN_CLUSTER_CONTEXT} >/dev/null 2>&1 || \
kubectl create ns ${FED_NAMESPACE} --context=${JOIN_CLUSTER_CONTEXT}

# === Step 2: Create ServiceAccount ===
kubectl get serviceaccount ${SA_NAME} -n ${FED_NAMESPACE} --context=${JOIN_CLUSTER_CONTEXT} >/dev/null 2>&1 || \
kubectl create serviceaccount ${SA_NAME} -n ${FED_NAMESPACE} --context=${JOIN_CLUSTER_CONTEXT}

# === Step 3: Create Token Secret (for K8s >= 1.24) ===
cat <<EOF | kubectl apply --context=${JOIN_CLUSTER_CONTEXT} -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${FED_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF

# === Step 4: Wait for token to be populated ===
echo "⏳ Waiting for ServiceAccount token to become ready..."
for i in {1..20}; do
  TOKEN=$(kubectl get secret ${SECRET_NAME} -n ${FED_NAMESPACE} --context=${JOIN_CLUSTER_CONTEXT} -o jsonpath='{.data.token}' 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    echo "✅ Token ready."
    break
  fi
  sleep 2
done

if [ -z "$TOKEN" ]; then
  echo "❌ Timeout: Token not found in secret ${SECRET_NAME}"
  exit 1
fi

# === Step 5: Run kubefedctl join ===
kubefedctl join ${JOIN_CLUSTER_CONTEXT} \
  --host-cluster-context=${HOST_CLUSTER_CONTEXT} \
  --cluster-context=${JOIN_CLUSTER_CONTEXT} \
  --secret-name=${SECRET_NAME} \
  --error-on-existing=false
  --v=2