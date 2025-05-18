#!/bin/bash

NAMESPACE="monitoring"
MAX_RETRIES=5
RETRY_INTERVAL=5

RELEASE_NAME=$(helm list -n "$NAMESPACE" -o json | jq -r '.[] | select(.name | startswith("kube-prometheus-stack")) | .name')

if [[ -z "$RELEASE_NAME" ]]; then
  echo "❌ No Prometheus release found in namespace '$NAMESPACE'."
  exit 1
fi

echo "✅ Found Prometheus Helm release: $RELEASE_NAME"

echo "🔧 Uninstalling Helm release '$RELEASE_NAME'..."
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"

sleep 30

RETRY=0
while true; do
  helm list -n "$NAMESPACE" -o json | jq -e --arg name "$RELEASE_NAME" '.[] | select(.name == $name)' > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "✅ Release '$RELEASE_NAME' has been successfully deleted."
    break
  fi

  if [[ $RETRY -ge $MAX_RETRIES ]]; then
    echo "❌ Failed to delete Helm release after $MAX_RETRIES attempts."
    exit 1
  fi

  echo "⌛ Release still exists. Retrying in ${RETRY_INTERVAL}s... (Attempt $((RETRY + 1))/$MAX_RETRIES)"
  sleep "$RETRY_INTERVAL"
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
  RETRY=$((RETRY + 1))
done