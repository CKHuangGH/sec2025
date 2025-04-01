#!/bin/bash
clusternumber=$1
echo "Searching for and terminating tcpdump-related processes..."
PIDS=$(pgrep -f "tcpdump")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All tcpdump processes have been terminated."
else
    echo "No tcpdump processes found."
fi

echo "Searching for and terminating bash-related processes..."
PIDS=$(pgrep -f "tophub")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All bash processes have been terminated."
else
    echo "No bash processes found."
fi

echo "Searching for and terminating bash-related processes..."
PIDS=$(pgrep -f "toppodwa")

if [ -n "$PIDS" ]; then
    echo "Found the following processes: $PIDS"
    kill -9 $PIDS
    echo "All bash processes have been terminated."
else
    echo "No bash processes found."
fi

for (( i=1; i<=$clusternumber; i++ )); do
    kubectl karmada unregister cluster$i --cluster-kubeconfig /root/.kube/cluster$i &
done

wait

sleep 10

for (( i=1; i<=$clusternumber; i++ )); do
    echo "Checking cluster$i ..."
    while kubectl --kubeconfig /root/.kube/cluster$i get pods -A 2>/dev/null | grep -q "karmada-agent"; do
        echo "[警告] cluster$i 仍存在 karmada-agent Pod嘗試再次進行 unregister..."
        kubectl karmada unregister cluster$i --cluster-kubeconfig /root/.kube/cluster$i
        sleep 5  # 可自行調整休息時間，避免一直密集呼叫
    done
    echo "cluster$i 中已無 karmada-agent Pod移除成功。"
done

sleep 10

echo "y" | kubectl karmada deinit

rm -rf /var/lib/karmada-etcd

rm -f ./number.txt

rm -f ./cross

rm -f ./kubetopPodHUB.csv