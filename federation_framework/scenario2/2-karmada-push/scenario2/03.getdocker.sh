number=$1
time=$2

mv kubetopPodHUB.csv /root/edgesys-2025/federation_framework/scenario2/karmada-push/scenario2/results/kubetopPodHUB.csv
mv cross /root/edgesys-2025/federation_framework/scenario2/karmada-push/scenario2/results/cross
mv number.txt /root/edgesys-2025/federation_framework/scenario2/karmada-push/scenario2/results/number.txt
sleep 5
scp -o StrictHostKeyChecking=no -r /root/edgesys-2025/federation_framework/scenario2/karmada-push/scenario2/results chuang@172.16.207.100:/home/chuang/results$number-$time-karmada-push

echo "-----------------------copy ok -------------------------------"