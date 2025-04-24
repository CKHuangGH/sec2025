number=$1
POD_THRESHOLD=0
SVC_THRESHOLD=1
SA_THRESHOLD=0

for ip in $(cat node_exec); do 
  ssh -o LogLevel=ERROR root@$ip . ./checking_svc_del.sh $SVC_THRESHOLD &
  ssh -o LogLevel=ERROR root@$ip . ./checking_sa_del.sh $SA_THRESHOLD &
  ssh -o LogLevel=ERROR root@$ip . ./checking_pod_del.sh $POD_THRESHOLD &
done

bash ./script/r$number.sh