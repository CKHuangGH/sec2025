#!/bin/bash

for ((i=1; i<=200; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | kubectl apply --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "deploy timestamps $(date +'%s.%N')" >> number.txt