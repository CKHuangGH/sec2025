read -p "please enter the test number(0, 60, 120, 180, 240, 300): " number

for (( times=0; times<2; times++ )); do
    bash ./script/init_reg.sh
    bash ./script/finish.sh
    sleep 20
    mkdir results
    bash ./script/run_stress_ocm.sh $number
    . ./03.getdocker.sh $number $times
    sleep 30
    . ./script/r$number.sh
    sleep 30
    for ip in $(cat node_exec)
    do 
	    ssh root@$ip . /root/edgesys-2025/federation_framework/scenario1/ocm/scenario1/reset_worker.sh
    done
    sleep 30
    . ./reset.sh
    rm -rf results
    sleep 30
done