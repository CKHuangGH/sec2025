#!/bin/bash

# Export the YAML of the monitoring namespace
kubectl get namespace monitoring -o yaml > monitoring-namespace.yaml
echo "✅ Exported monitoring namespace to monitoring-namespace.yaml"

# Find the ServiceAccount name matching kube-prometheus-stack-*-prometheus
SA_NAME=$(kubectl get sa -n monitoring --no-headers -o custom-columns=":metadata.name" | grep '^kube-prometheus-stack-.*-prometheus$')

if [ -z "$SA_NAME" ]; then
  echo "❌ No matching ServiceAccount found"
  exit 1
fi

# Export the ServiceAccount's YAML
kubectl get sa "$SA_NAME" -n monitoring -o yaml > "sa.yaml"
echo "✅ Exported ServiceAccount $SA_NAME to sa.yaml"

# Find the matching ClusterRoleBinding name
CRB_NAME=$(kubectl get clusterrolebinding --no-headers -o custom-columns=":metadata.name" | grep "^${SA_NAME}$")

if [ -z "$CRB_NAME" ]; then
  echo "❌ No matching ClusterRoleBinding found"
  exit 1
fi

# Export the ClusterRoleBinding's YAML
kubectl get clusterrolebinding "$CRB_NAME" -o yaml > "crb.yaml"
echo "✅ Exported ClusterRoleBinding $CRB_NAME to crb.yaml"

echo "🎉 All resources exported successfully!"

# Set base name
BASE_NAME="kube-prometheus-stack"
OUTPUT_FILE="patched-clusterrole.yaml"

# Automatically find the matching ClusterRole name (metadata.name only)
CLUSTERROLE_NAME=$(kubectl get clusterrole -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "${BASE_NAME}-.*-prometheus" | head -n1)

if [ -z "$CLUSTERROLE_NAME" ]; then
  echo "❌ No ClusterRole matching ${BASE_NAME}-*-prometheus format found!"
  exit 1
fi

echo "🔎 Found ClusterRole: ${CLUSTERROLE_NAME}"

# Export the original ClusterRole
kubectl get clusterrole ${CLUSTERROLE_NAME} -o yaml > original-clusterrole.yaml

# Check if export succeeded
if [ $? -ne 0 ]; then
  echo "❌ Failed to export ClusterRole!"
  exit 1
fi

# Use awk to insert a new rule
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

echo "✅ Modified ClusterRole saved to ${OUTPUT_FILE}"

# Patch the original ClusterRole online
echo "🚀 Patching ClusterRole online..."

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
  echo "✅ Online patch successful!"
else
  echo "❌ Online patch failed. Please check manually."
fi

#!/bin/bash
kubectl apply -f monitoring-namespace.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f sa.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f crb.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
kubectl apply -f patched-clusterrole.yaml --kubeconfig /etc/karmada/karmada-apiserver.config

# File paths
CLUSTERROLE_FILE="patched-clusterrole.yaml"
SECRET_FILE="/root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/secret.yaml"
TEMP_FILE="secret.tmp.yaml"

# Get metadata.name from ClusterRole
SERVICE_ACCOUNT_NAME=$(awk '/metadata:/ {in_metadata=1} in_metadata && /^[[:space:]]*name:/ { print $2; exit }' "$CLUSTERROLE_FILE")
echo "ServiceAccount name obtained: $SERVICE_ACCOUNT_NAME"

# Ensure name was captured
if [[ -z "$SERVICE_ACCOUNT_NAME" ]]; then
  echo "Could not find metadata.name in ClusterRole"
  exit 1
fi

# Update service-account.name field in secret.yaml
awk -v newname="$SERVICE_ACCOUNT_NAME" '
  BEGIN { changed = 0 }
  {
    if ($0 ~ /^[[:space:]]*kubernetes.io\/service-account.name:/) {
      indent = match($0, /[^ ]/) - 1
      printf "%*s%s: \"%s\"\n", indent, "", "kubernetes.io/service-account.name", newname
      changed = 1
    } else {
      print
    }
  }
  END {
    if (!changed) {
      print "Field kubernetes.io/service-account.name not found, please check format" > "/dev/stderr"
      exit 1
    }
  }
' "$SECRET_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SECRET_FILE"

echo "✅ Updated service-account.name in secret.yaml to: $SERVICE_ACCOUNT_NAME"

kubectl apply -f ./script/secret.yaml --kubeconfig /etc/karmada/karmada-apiserver.config

# Set variables
KUBECONFIG_PATH="/etc/karmada/karmada-apiserver.config"
SECRET_NAME="prometheus"
NAMESPACE="monitoring"
VALUES_FILE="/root/sec2025/federation_framework/scenario1/karmada-push/values.yaml"

# Retrieve and decode token
TOKEN=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" \
  -o=jsonpath="{.data.token}" --kubeconfig "$KUBECONFIG_PATH" | base64 -d)

# Check if token was successfully retrieved
if [[ -z "$TOKEN" ]]; then
  echo "❌ Failed to retrieve or decode token. Please check if the secret exists."
  exit 1
fi

# Escape special characters
ESCAPED_TOKEN=$(printf '%s\n' "$TOKEN" | sed -e 's/[\/&]/\\&/g')

# Replace the entire bearer_token line using sed
sed -i -E "s/^([[:space:]]*)bearer_token:.*/\1bearer_token: $ESCAPED_TOKEN/" "$VALUES_FILE"


echo "✅ Successfully updated bearer_token in $VALUES_FILE"

# Find the Helm release name (starting with kube-prometheus-stack)
RELEASE_NAME=$(helm list -n monitoring -o json | jq -r '.[] | select(.name | startswith("kube-prometheus-stack")) | .name')

# Check if release was found
if [ -z "$RELEASE_NAME" ]; then
  echo "No Helm release found for kube-prometheus-stack"
  exit 1
fi

echo "Found release: $RELEASE_NAME"

# Execute helm upgrade
helm upgrade "$RELEASE_NAME" prometheus-community/kube-prometheus-stack \
  --version 70.4.2 \
  --namespace monitoring \
  --values /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/values.yaml \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.service.type=NodePort \
  --set prometheus.prometheusSpec.scrapeInterval="5s" \
  --set prometheus.prometheusSpec.enableAdminAPI=true \
  --set prometheus.prometheusSpec.resources.requests.cpu="1000m" \
  --set prometheus.prometheusSpec.resources.requests.memory="1024Mi"