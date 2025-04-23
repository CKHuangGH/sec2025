number=$1
SCRIPT_PATH="/root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/script/checking_kpull_del.py"
NAMESPACE="default"
POD_THRESHOLD=0
SVC_THRESHOLD=1
SA_THRESHOLD=0

for ip in $(cat node_exec); do 
  ssh -o LogLevel=ERROR root@"$ip" "\
    python3 $SCRIPT_PATH \
      --namespace $NAMESPACE \
      --pod-threshold $POD_THRESHOLD \
      --svc-threshold $SVC_THRESHOLD \
      --sa-threshold $SA_THRESHOLD \
  "
done

. ./script/r$number.sh