number=$1
SCRIPT_PATH="/root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/checking_kpull.py"
NAMESPACE="default"
POD_THRESHOLD=$((number * 11))
SVC_THRESHOLD=$((number * 11)+1)
SA_THRESHOLD=$((number * 11))


while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 2 "$ip" > number.txt
done < "node_list"

echo $number
echo $number >> number.txt
echo "start deployment" >> number.txt
echo $(date +'%s.%N') >> number.txt

sudo tcpdump -i ens3 -nn -q '(src net 10.176.0.0/16 and dst net 10.176.0.0/16) and not arp and not tcp port 22 and not icmp' >> cross &

sleep 120

. ./script/$number.sh > /dev/null 2>&1 &

for ip in $(cat node_exec)
do 
  ssh -o LogLevel=ERROR root@"$ip" "\
    nohup python3 $SCRIPT_PATH \
      --namespace $NAMESPACE \
      --pod-threshold $POD_THRESHOLD \
      --svc-threshold $SVC_THRESHOLD \
      --sa-threshold $SA_THRESHOLD \
    > /dev/null 2>&1 &" < /dev/null
done

echo "wait for 900 secs"
for (( i=900; i>0; i-- )); do
    printf "\r%4d secs remaining..." "$i"
    sleep 1
done

python3 getmetrics_cpuram_time.py
python3 getmetrics_cpuram_average10.py

. ./script/copy.sh