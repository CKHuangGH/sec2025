number=$1
time=$2
j=1

for i in $(cat node_exec)
do
	scp root@$i:/root/time.txt /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/time.txt
	scp root@$i:/root/resource_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_avg_10min_member.csv
	scp root@$i:/root/resource_all.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_all_member.csv
	scp root@$i:/root/apiserver_metrics_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/apiserver_metrics_avg_10min_member.csv
	scp root@$i:/root/controller_extended_metrics.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/controller_extended_metrics.csv_member.csv
	j=$((j+1))	
done


mv /root/controller_extended_metrics.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/controller_extended_metrics.csv
mv /root/apiserver_metrics_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/apiserver_metrics_avg_10min.csv
mv /root/resource_avg_10min.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_avg_10min.csv
mv /root/resource_all.csv /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/resource_all.csv
mv cross /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/cross
mv number.txt /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/number.txt
mv clusterstatus.txt /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results/clusterstatus.txt

sleep 5
scp -o StrictHostKeyChecking=no -r /root/sec2025/federation_framework/scenario1/karmada-pull/scenario1/results chuang@172.16.79.101:/home/chuang/results$number-$time-karmada-pull