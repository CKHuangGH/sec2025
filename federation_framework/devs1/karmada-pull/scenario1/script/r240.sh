#!/bin/bash

batch_size=12
total=240

for ((start=1; start<=total; start+=batch_size)); do
  end=$((start + batch_size - 1))
  if (( end > total )); then
    end=$total
  fi

  for ((i=start; i<=end; i++)); do
    export ID=$i
    envsubst < ./script/google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f - &
  done

  wait  # 等待這一輪 12 個指令都跑完
done

echo "deploy timestamps $(date +'%s.%N')" >> number.txt
