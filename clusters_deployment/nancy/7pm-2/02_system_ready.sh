#!/bin/bash

manage=$(awk NR==1 node_list)

git clone https://github.com/CKHuangGH/sec2025

rm -rf /home/chuang/.ssh/known_hosts

for j in $(cat node_list)
do
    scp /home/chuang/.ssh/id_rsa root@$j:/root/.ssh
    scp -r ./sec2025 root@$j:/root/
done

echo "wait for 30 secs"
sleep 30

i=0
for j in $(cat node_list)
do
ssh -o StrictHostKeyChecking=no root@$j scp -o StrictHostKeyChecking=no /root/.kube/config root@$manage:/root/.kube/cluster$i
ssh -o StrictHostKeyChecking=no root@$j chmod 777 -R /root/sec2025/
i=$((i+1))
done

scp -r /home/chuang/addon root@$manage:/root/
scp -r /home/chuang/karmada_package root@$manage:/root/
scp -r /home/chuang/images_system root@$manage:/root/
scp -r /home/chuang/images_google root@$manage:/root/
# scp -r /home/chuang/ocm_package root@$manage:/root/

# scenario1
scp node_list root@$manage:/root/sec2025/federation_framework/scenario1/ocm/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario1/karmada-pull/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario1/karmada-push/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario1/kubefed/node_list

# scenario2
scp node_list root@$manage:/root/sec2025/federation_framework/scenario2/ocm/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario2/karmada-pull/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario2/karmada-push/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario2/kubefed/node_list

# scenario3
scp node_list root@$manage:/root/sec2025/federation_framework/scenario3/ocm/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario3/karmada-pull/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario3/karmada-push/node_list
scp node_list root@$manage:/root/sec2025/federation_framework/scenario3/kubefed/node_list
echo "management node is $manage"