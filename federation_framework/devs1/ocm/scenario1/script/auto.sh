#!/bin/bash

# Define a function to run the script on a given node with retries if it fails
run_on_node() {
  local node="$1"
  local cluster="$2"

  local target="<cluster_name>"
  local replacement="cluster${cluster}"

  local input_file="run.sh"
  local newname="run${cluster}.sh"
  local temp_file="temp_file.sh"

  # Use sed to generate the script with the replaced cluster name
  sed "s/$target/$replacement/g" "$input_file" > "$temp_file"
  mv "$temp_file" "$newname"

  # Loop until the execution is successful
  while true; do
    echo "Executing $newname on node $node ..."
    output=$(ssh root@"$node" 'bash -s' < "$newname" 2>&1)
    ret=$?
    echo "$output"

    # Check if the exit code is 0 and output does not contain the error message
    if [ $ret -eq 0 ] && [[ "$output" != *"Error: unexpected watch event received"* ]]; then
      echo "Execution on node $node succeeded."
      break
    else
      echo "Execution on node $node failed. Retrying in 5 seconds..."
      sleep 5
    fi
  done
}

cluster=1
# Read nodes from the node_list file, one per line
while read -r node; do
  run_on_node "$node" "$cluster" &
  cluster=$((cluster+1))
done < node_list

# Wait for all background processes to complete
wait
