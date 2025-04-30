number=$1
time=$2
j=1

for i in $(cat node_exec)
do
	scp root@$i:/root/time.txt /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/time.txt
	scp root@$i:/root/resource_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_avg_10min_member.csv
	scp root@$i:/root/resource_all.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_all_member.csv
	j=$((j+1))	
done

mv /root/resource_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_avg_10min.csv
mv /root/resource_all.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_all.csv
mv cross /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/cross
mv number.txt /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/number.txt

sleep 5
scp -o StrictHostKeyChecking=no -r /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results chuang@172.16.207.100:/home/chuang/results$number-$time-karmada-pull