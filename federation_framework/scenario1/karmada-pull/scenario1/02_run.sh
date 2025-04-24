#!/bin/bash

read -p "please enter the test number(200, 400, 600, 800, 1000): " number

for (( times=0; times<10; times++ )); do
    bash ./script/init_reg.sh
    sleep 30
    kubectl --kubeconfig /etc/karmada/karmada-apiserver.config apply -f ./script/propagationpolicy.yaml
    mkdir results
    bash ./script/run_stress_kpull.sh $number
    sleep 30
    bash ./script/delete.sh $number
    sleep 30
    bash ./script/getdocker.sh $number $times
    bash ./script/reset.sh
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/reset_worker.sh
    done
    rm -rf results
    sleep 30
done

bash ./script/copy.sh $number

for ip in $(cat node_exec)
do
	ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/copy.sh $number
	scp root@$ip:/root/prom-$number/ /root/prom-$number/
	j=$((j+1))	
done

scp -o StrictHostKeyChecking=no -r /root/prom-$number/ chuang@172.16.207.100:/home/chuang/results$number-karmada-pull