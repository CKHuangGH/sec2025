#!/bin/bash

number=$1

echo "Searching for and terminating tcpdump-related processes..."
PIDS=$(pgrep -f "tcpdump")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All tcpdump processes have been terminated."
else
    echo "No tcpdump processes found."
fi

sleep 5

for i in $(seq 1 1); do
    # Retrieve CSR names that match the pattern "cluster<i>-"
    csr_names=$(kubectl get csr --no-headers -o custom-columns=NAME:.metadata.name | grep "^cluster${i}-")
    
    # If no CSR is found for this cluster number, output a message and continue to the next number.
    if [ -z "$csr_names" ]; then
        echo "No CSR found for cluster${i}"
        continue
    fi

    # Loop through each CSR name that matches the pattern and delete it.
    for csr in $csr_names; do
        echo "Deleting CSR: $csr"
        kubectl delete csr "$csr"
    done
done

kubectl delete mcl cluster1

sleep 5

while true; do
    echo "clusteradm clean ..."
    clusteradm clean

    if [ $? -eq 0 ]; then
        echo "done"
        break
    else
        echo "fail and clean again"
        sleep 5
    fi
done
sleep 5
for ((i=1; i<=1; i++)); do
    kubectl delete ns cluster$i
done

rm -rf /root/prom-$number/

rm -rf /root/prom-$number-member/

rm -f /root/number.txt

rm -f ../number.txt

rm -f ../cross

kubectl delete ns monitoring