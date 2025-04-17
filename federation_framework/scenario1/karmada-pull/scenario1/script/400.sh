#!/bin/bash

MAX_PARALLEL=10
count=0

for ((i=1; i<=400; i++)); do
  export ID=$i
  envsubst < google_demo.yaml | kubectl apply --kubeconfig /etc/karmada/karmada-apiserver.config -f - &

  ((count++))
  if (( count % MAX_PARALLEL == 0 )); then
    wait  # 等待目前所有背景工作完成
  fi
done

# 等待所有剩下的背景任務結束
wait

echo "All $i deployments created." >> number.txt
date +'%s.%N' >> number.txt
