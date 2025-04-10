#!/bin/bash

for ((i=1; i<=1 i++)); do
  export ID=$i
  envsubst < run.yaml | kubectl apply --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "All $i deployments created." >> number.txt
date +'%s.%N' >> number.txt