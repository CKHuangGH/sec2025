#!/bin/bash

read -p "please enter the test number(0, 60, 120, 180, 240, 300): " number

for (( times=0; times<7; times++ )); do
    bash ./script/deployprometheus.sh
    sleep 60
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip bash /root/sec2025/federation_framework/scenario1/ocm/scenario1/script/deployprometheus-member.sh
    done
    sleep 60
    bash ./script/init_reg.sh
    bash ./script/auto.sh
    sleep 20
    bash ./script/finish.sh
    sleep 30
    mkdir results
    bash ./script/timedelay.sh
    bash ./script/run_stress.sh $number
    sleep 30
    bash ./script/delete.sh $number
    sleep 60
    bash ./reset_delay.sh
    sleep 5
    python3 ./script/getmetrics_cpuram_time.py
    sleep 10
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip python3 /root/sec2025/federation_framework/scenario1/ocm/scenario1/script/getmetrics_cpuram_time_member.py
    done
    sleep 10
    bash ./script/getdocker.sh $number $times
    # bash ./script/copyprom.sh $number $times
    bash ./script/reset.sh $number
    bash ./script/deleteprometheus.sh
    sleep 60
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip bash /root/sec2025/federation_framework/scenario1/ocm/scenario1/script/reset_worker.sh $number
        ssh root@$ip bash /root/sec2025/federation_framework/scenario1/ocm/scenario1/script/deleteprometheus.sh 
    done
    rm -rf results
    sleep 60
done