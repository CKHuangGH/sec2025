#!/bin/bash

for ((i=1; i<=2; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | clusteradm create work demo$i --clusters cluster1 -f - &
done

echo "deploy timestamps $(date +'%s.%N')" >> number.txt