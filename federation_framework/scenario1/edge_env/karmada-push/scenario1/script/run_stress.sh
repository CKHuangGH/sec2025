number=$1
POD_THRESHOLD=$(( number * 10 ))
SVC_THRESHOLD=$(( number * 10 + 1 ))
SA_THRESHOLD=$(( number * 10 + 1 ))

while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 60 "$ip" > number.txt
done < "node_exec"

echo $number
echo $number >> number.txt

#sudo tcpdump -i ens3 -nn -q '(src net 10.176.0.0/16 and dst net 10.176.0.0/16) and not arp and not tcp port 22 and not icmp and tcp[((tcp[12] & 0xf0) >> 2):4] != 0' >> cross &

sudo tcpdump -i ens3 -nn -q '(src net 10.144.0.0/16 and dst net 10.144.0.0/16) and not arp and not tcp port 22 and not icmp and tcp[((tcp[12] & 0xf0) >> 2):4] != 0' >> cross &

sleep 120

echo "start deployment $(date +'%s.%N')" >> number.txt
for ip in $(cat node_exec); do 
  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/timesave.sh "start deployment"
done
cp ./number.txt /root/number.txt

bash ./script/$number.sh > /dev/null 2>&1 &

for ip in $(cat node_exec); do 
  ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/checking_pod.sh $POD_THRESHOLD
done

for (( i=900; i>0; i-- )); do
    printf "\r%4d secs remaining..." "$i"
    sleep 1
done

echo "calc cpuram average time $(date +'%s.%N')" >> number.txt
python3 ./script/getmetrics_cpuram_average10.py #ok
sleep 2

echo "calc management karmada api average time $(date +'%s.%N')" >> number.txt
python3 ./script/getmetrics_latency_average10_karmada.py #ok
sleep 2

echo "calc management karmada controller average time $(date +'%s.%N')" >> number.txt
python3 ./script/getmetrics_controller_average10_karmada.py #ok
sleep 2

for ip in $(cat node_exec); do 

  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/timesave.sh "calc cpuram average time"
  ssh -o LogLevel=ERROR root@$ip python3 /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/getmetrics_cpuram_average10_member.py #ok
  sleep 2

  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/timesave.sh "calc member k8s api time"
  ssh -o LogLevel=ERROR root@$ip python3 /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/getmetrics_latency_average10.py #ok
  sleep 2

  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/timesave.sh "calc member k8s controller time"
  ssh -o LogLevel=ERROR root@$ip python3 /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/getmetrics_controller_average10.py #ok
  sleep 2
done

echo "========== Kubernetes Status for cluster0 ==========" > clusterstatus.txt
echo "" >> clusterstatus.txt
sleep 2
echo "== Nodes ==" >> clusterstatus.txt
kubectl get nodes --context=cluster0 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt
sleep 2
echo "== Pods (All namespaces) ==" >> clusterstatus.txt
kubectl get pods --all-namespaces --context=cluster0 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt
sleep 2
echo "========== Kubernetes Status for cluster1 ==========" >> clusterstatus.txt
echo "" >> clusterstatus.txt
sleep 2
echo "== Nodes ==" >> clusterstatus.txt
kubectl get nodes --context=cluster1 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt
sleep 2
echo "== Pods (All namespaces) ==" >> clusterstatus.txt
kubectl get pods --all-namespaces --context=cluster1 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt
sleep 2