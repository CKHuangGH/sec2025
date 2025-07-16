number=$1
time=$2

bash /root/sec2025/federation_framework/scenario1/liqo/scenario1/script/copy.sh $number

for ip in $(cat node_exec)
do
	ssh root@$ip bash /root/sec2025/federation_framework/scenario1/liqo/scenario1/script/copy.sh $number
	scp -r root@$ip:/root/prom-$number/ /root/prom-$number-member/
	j=$((j+1))	
done

scp -o StrictHostKeyChecking=no -r /root/prom-$number-member/ chuang@172.16.79.101:/home/chuang/prombackup-$number-$time-liqo-member
scp -o StrictHostKeyChecking=no -r /root/prom-$number/ chuang@172.16.79.101:/home/chuang/prombackup-$number-$time-liqo