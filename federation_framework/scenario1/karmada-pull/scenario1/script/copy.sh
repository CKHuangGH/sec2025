#!/bin/bash
number=$1
# Automatically retrieve the IP address of network interface ens3 (excluding 127.0.0.1)
PROMETHEUS_IP=$(ip -4 addr show ens3 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PROMETHEUS_PORT=30090
NAMESPACE=monitoring
EXPORT_DIR=/root/prom-$number/prometheus-snapshot-$PROMETHEUS_IP

# Verify that the IP address was successfully retrieved
if [ -z "$PROMETHEUS_IP" ]; then
  echo "❌ Failed to get IP from interface ens3. Please verify the interface name."
  exit 1
fi

echo "🌐 Prometheus is accessible at: http://$PROMETHEUS_IP:$PROMETHEUS_PORT"

# Automatically retrieve the Prometheus pod name using its label
PROMETHEUS_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=prometheus -o jsonpath="{.items[0].metadata.name}")

# Ensure the Prometheus pod was found
if [ -z "$PROMETHEUS_POD" ]; then
  echo "❌ Failed to find Prometheus Pod."
  exit 1
fi

echo "🎯 Found Prometheus Pod: $PROMETHEUS_POD"

# Call the Prometheus Admin API to create a snapshot
echo "📸 Creating snapshot..."
curl -s -XPOST http://$PROMETHEUS_IP:$PROMETHEUS_PORT/api/v1/admin/tsdb/snapshot > snapshot.json

# Extract the snapshot folder name from the API response
SNAPSHOT_NAME=$(grep -oP '(?<="name":")[^"]+' snapshot.json)

# Validate the snapshot creation result
if [ -z "$SNAPSHOT_NAME" ]; then
  echo "❌ Snapshot creation failed. Response:"
  cat snapshot.json
  exit 1
fi

echo "✅ Snapshot created successfully: $SNAPSHOT_NAME"

# Create a local directory to store the snapshot
mkdir -p $EXPORT_DIR

# Copy the snapshot folder from the Prometheus pod to the local machine
echo "📦 Copying snapshot..."
kubectl cp "$NAMESPACE/$PROMETHEUS_POD:/prometheus/snapshots/$SNAPSHOT_NAME" "$EXPORT_DIR" -c prometheus

echo "✅ Export complete! Snapshot saved at: $EXPORT_DIR/$SNAPSHOT_NAME"
