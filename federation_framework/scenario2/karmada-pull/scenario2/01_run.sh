read -p "please enter the test number(1, 50, 100, 150, 200): " number

for (( times=0; times<12; times++ )); do
    . ./init_reg.sh $number
    sleep 30
    mkdir results
    . ./02_run_stress_kpull.sh $number
    . ./03.getdocker.sh $number $times
    sleep 30
    . ./reset.sh $number
    for ip in $(cat node_list)
    do 
	    ssh root@$ip . /root/edgesys-2025/federation_framework/scenario2/karmada-pull/scenario2/reset_worker.sh
    done
    rm -rf results
    sleep 30
done