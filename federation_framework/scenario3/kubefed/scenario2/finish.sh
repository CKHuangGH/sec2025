#!/bin/bash
number=$1
# Determine the number of clusters based on the number of lines in the node_list file.
max_clusters=$(wc -l < node_list)
echo "Number of clusters determined from node_list: $max_clusters"

# Define the desired adjusted namespace count.
# Adjust this value as needed for your environment.
DESIRED_NS_COUNT=$number

# Function to accept clusters using generated cluster names (cluster1, cluster2, ..., clusterN)
accept_clusters() {
  for i in $(seq 1 "$max_clusters"); do
    cluster_name="cluster${i}"
    echo "Accepting cluster: $cluster_name"
    clusteradm accept --clusters "$cluster_name"
  done
}

# Function to calculate the adjusted namespace count.
# It retrieves the total number of namespaces (excluding header) and subtracts 6.
get_adjusted_ns_count() {
  ns_count=$(kubectl get ns --no-headers | wc -l)
  echo $(( ns_count - 6 ))
}

# Main loop: repeat the cluster acceptance process until the adjusted namespace count equals the desired value.
while true; do
  echo "Accepting clusters..."
  accept_clusters

  echo "Waiting 10 seconds for changes to propagate..."
  sleep 10

  adjusted_ns_count=$(get_adjusted_ns_count)
  echo "Current adjusted namespace count: $adjusted_ns_count"

  if [ "$adjusted_ns_count" -eq "$DESIRED_NS_COUNT" ]; then
    echo "Desired namespace count of $DESIRED_NS_COUNT reached."
    break
  else
    echo "Namespace count is not $DESIRED_NS_COUNT. Repeating cluster acceptance..."
  fi
done
