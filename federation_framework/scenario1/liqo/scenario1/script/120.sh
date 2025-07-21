#!/bin/bash

batch_size=10
total=120

for ((start=1; start<=total; start+=batch_size)); do
  end=$((start + batch_size - 1))
  if (( end > total )); then
    end=$total
  fi

  for ((i=start; i<=end; i++)); do
    export ID=$i
    envsubst < ./script/google_demo.yaml | kubectl apply -n default -f - &
  done

  wait
done

echo "deploy timestamps $(date +'%s.%N')" >> number.txt
