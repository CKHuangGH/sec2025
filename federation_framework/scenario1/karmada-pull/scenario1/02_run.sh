read -p "please enter the test number(200, 400, 600, 800, 1000): " number

for (( times=0; times<10; times++ )); do
    . ./script/init_reg.sh
    sleep 30
    kubectl --kubeconfig /etc/karmada/karmada-apiserver.config apply -f ./script/propagationpolicy.yaml
    mkdir results
    . ./script/run_stress_kpull.sh $number
    . ./script/getdocker.sh $number $times
    sleep 30
    . ./script/r$number.sh
    sleep 30
    . ./reset.sh
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip . /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/reset_worker.sh
    done
    rm -rf results
    sleep 30
done