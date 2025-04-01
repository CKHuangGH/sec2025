#!/bin/bash
# Switch to the specified Kubernetes context
kubectl config use-context cluster0

# Continuously attempt to run clusteradm init until it succeeds
while true; do
    echo "Attempting to run clusteradm init..."
    # Run clusteradm init and redirect all output (stdout and stderr) to temp.sh
    if clusteradm init --wait --context cluster0 > temp.sh 2>&1; then
        # Check if the expected keyword "clusteradm join" is present in the output
        if grep -q "clusteradm join" temp.sh; then
            echo "clusteradm init succeeded!"
            grep "clusteradm join" temp.sh > run.sh
            break
        else
            echo "Warning: Initialization executed, but 'clusteradm join' keyword not found. Retrying..."
        fi
    else
        echo "Error: clusteradm init execution failed. Retrying..."
    fi
    sleep 10
done

# Remove the NoSchedule taint from the control-plane on all nodes listed in 'node_list'
for i in $(cat node_list)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

sleep 10

./auto.sh