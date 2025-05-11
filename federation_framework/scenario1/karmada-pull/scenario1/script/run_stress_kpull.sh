number=$1
POD_THRESHOLD=$(( number * 10 ))
SVC_THRESHOLD=$(( number * 10 + 1 ))
SA_THRESHOLD=$(( number * 10 + 1 ))

while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 2 "$ip" > number.txt
done < "node_list"

echo $number
echo $number >> number.txt

# sudo tcpdump -i ens3 -nn -q '(src net 10.176.0.0/16 and dst net 10.176.0.0/16) and not arp and not tcp port 22 and not icmp and tcp[((tcp[12] & 0xf0) >> 2):4] != 0' >> cross &

sudo tcpdump -i ens3 -nn -q '(src net 10.144.0.0/16 and dst net 10.144.0.0/16) and not arp and not tcp port 22 and not icmp and tcp[((tcp[12] & 0xf0) >> 2):4] != 0' >> cross &

sleep 120

echo "start deployment $(date +'%s.%N')" >> number.txt
for ip in $(cat node_exec); do 
  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/timesave.sh "start deployment"
done
cp ./number.txt /root/number.txt

bash ./script/$number.sh > /dev/null 2>&1 &

for ip in $(cat node_exec); do 
  # ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/checking_svc.sh $SVC_THRESHOLD &
  # ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/checking_sa.sh $SA_THRESHOLD &
  ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/checking_pod.sh $POD_THRESHOLD
done

for (( i=900; i>0; i-- )); do
    printf "\r%4d secs remaining..." "$i"
    sleep 1
done

python3 ./script/getmetrics_cpuram_time.py
echo "calc average time $(date +'%s.%N')" >> number.txt
python3 ./script/getmetrics_cpuram_average10.py

for ip in $(cat node_exec); do 
  ssh -o LogLevel=ERROR root@$ip python3 /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/getmetrics_cpuram_time_member.py
  ssh -o LogLevel=ERROR root@$ip python3 /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/getmetrics_cpuram_average10_member.py
done

echo "========== Kubernetes Status for cluster0 ==========" > clusterstatus.txt
echo "" >> clusterstatus.txt

echo "== Nodes ==" >> clusterstatus.txt
kubectl get nodes --context=cluster0 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt

echo "== Pods (All namespaces) ==" >> clusterstatus.txt
kubectl get pods --all-namespaces --context=cluster0 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt

echo "========== Kubernetes Status for cluster1 ==========" >> clusterstatus.txt
echo "" >> clusterstatus.txt

echo "== Nodes ==" >> clusterstatus.txt
kubectl get nodes --context=cluster1 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt

echo "== Pods (All namespaces) ==" >> clusterstatus.txt
kubectl get pods --all-namespaces --context=cluster1 >> clusterstatus.txt 2>&1
echo "" >> clusterstatus.txt