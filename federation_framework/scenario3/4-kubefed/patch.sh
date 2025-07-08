#!/bin/bash

set -e  # Enable error detection, any error will terminate the script

CONFIG_FILE="/etc/containerd/config.toml"
BACKUP_FILE="/etc/containerd/config.toml.bak"

# **Backup the original configuration file**
echo "🔄 Backing up $CONFIG_FILE to $BACKUP_FILE"
sudo cp $CONFIG_FILE $BACKUP_FILE

# **Modify containerd configuration**
echo "🛠 Updating containerd registry configuration"

# Ensure `[plugins."io.containerd.grpc.v1.cri".registry]` exists
if ! grep -q '\[plugins."io.containerd.grpc.v1.cri".registry\]' $CONFIG_FILE; then
    echo -e "\n[plugins.\"io.containerd.grpc.v1.cri\".registry]\n" | sudo tee -a $CONFIG_FILE > /dev/null
fi

# Check if `docker.io` already has a mirror configuration, update if exists, otherwise add a new one
if grep -q '\[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"\]' $CONFIG_FILE; then
    sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"\]/,/endpoint/d' $CONFIG_FILE
fi

# Add or replace the `docker.io` mirror endpoint
sudo tee -a $CONFIG_FILE > /dev/null <<EOL
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
  endpoint = ["http://docker-cache.grid5000.fr"]
EOL

echo "✅ Registry mirror updated to http://docker-cache.grid5000.fr"

# **Restart containerd**
echo "🔄 Restarting containerd..."
sudo systemctl restart containerd

# **Verify if containerd is running successfully**
if systemctl is-active --quiet containerd; then
    echo "✅ containerd restarted successfully!"
else
    echo "❌ containerd failed to start, please check $CONFIG_FILE"
    exit 1
fi