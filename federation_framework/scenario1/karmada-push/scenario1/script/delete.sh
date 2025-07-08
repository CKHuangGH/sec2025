number=$1
POD_THRESHOLD=0
SVC_THRESHOLD=1
SA_THRESHOLD=1

for ip in $(cat node_exec); do 
  ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/timesave.sh "start cleanup timestamps"
done
bash ./script/r$number.sh &

for ip in $(cat node_exec); do 
  # ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/checking_svc_del.sh $SVC_THRESHOLD &
  # ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/checking_sa_del.sh $SA_THRESHOLD &
  ssh -o LogLevel=ERROR root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/checking_pod_del.sh $POD_THRESHOLD
done