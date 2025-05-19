number=$1
time=$2

bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/copy.sh $number

for ip in $(cat node_exec)
do
	ssh root@$ip bash /root/sec2025/federation_framework/scenario1/karmada-push/scenario1/script/copy.sh $number
	scp -r root@$ip:/root/prom-$number/ /root/prom-$number-member/
	j=$((j+1))	
done

scp -o StrictHostKeyChecking=no -r /root/prom-$number-member/ chuang@172.16.207.100:/home/chuang/prombackup-$number-$time-karmada-push-member
scp -o StrictHostKeyChecking=no -r /root/prom-$number/ chuang@172.16.207.100:/home/chuang/prombackup-$number-$time-karmada-push