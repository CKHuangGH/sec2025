read -p "please enter the test number(2000, 4000, 6000, 8000, 10000): " number

for (( times=0; times<10; times++ )); do
    . ./init_reg.sh
    sleep 30
    kubectl apply -f ./propagationpolicy.yaml --kubeconfig /etc/karmada/karmada-apiserver.config
    mkdir results
    . ./02_run_stress_kpull.sh $number
    . ./03.getdocker.sh $number $times
    sleep 30
    . ./script/r$number.sh
    sleep 30
    . ./reset.sh
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip . /root/edgesys-2025/federation_framework/scenario1/karmada-pull/scenario1/reset_worker.sh
    done
    rm -rf results
    sleep 30
done