number=$1

mkdir /var/log/ntpsec
pip3 install kubernetes --break-system-packages
sudo apt install tcpdump -y
sudo systemctl stop ntp
sudo ntpd -gq
sudo systemctl start ntp

for i in `seq 0 $number`
do
    sed -i 's/kubernetes-admin/k8s-admin-cluster'$i'/g' ~/.kube/cluster$i
    sed -i 's/name: kubernetes/name: cluster'$i'/g' ~/.kube/cluster$i
    sed -i 's/cluster: kubernetes/cluster: cluster'$i'/g' ~/.kube/cluster$i
done

for i in `seq 0 $number`
do
    string=$string"/root/.kube/cluster$i:"
done

string=$string | sed "s/.$//g"
KUBECONFIG=$string kubectl config view --flatten > ~/.kube/config

for i in `seq 0 $number`
do
    kubectl config rename-context k8s-admin-cluster$i@kubernetes cluster$i
done

sleep 5

sed -i 's|--listen-metrics-urls=http://127.0.0.1:2381|--listen-metrics-urls=http://0.0.0.0:2381|' "/etc/kubernetes/manifests/etcd.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-scheduler.yaml"
sleep 30
sed -i 's|--bind-address=127.0.0.1|--bind-address=0.0.0.0|' "/etc/kubernetes/manifests/kube-controller-manager.yaml"
sleep 60

while read line
do 
echo $line
ip1=$(echo $line | cut -d "." -f 2)
ip2=$(echo $line | cut -d "." -f 3)
break
done < node_list_all

ip=$(cat node_list)

> node_ip_all
> node_ip

for i in {1..252}; do
  new_ip=$(echo "$ip" | sed "s/\.[0-9]*$/.${i}/")
  echo "$new_ip" >> node_ip_all
done

tail -n +2 node_ip_all > node_ip

while IFS= read -r ip_address; do
  scp -o StrictHostKeyChecking=no /root/sec2025/federation_framework/scenario1/ocm/node_ip_all root@$ip_address:/root/
  scp -o StrictHostKeyChecking=no /root/sec2025/federation_framework/scenario1/ocm/ntp.sh root@$ip_address:/root/
done < "node_ip_all"

while IFS= read -r ip_address; do
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" mkdir -p /var/log/ntpsec
  ssh -n -o StrictHostKeyChecking=no root@"$ip_address" "nohup bash /root/ntp.sh > /var/log/ntpsec/ntp.log 2>&1 &"
done < node_ip_all

while IFS= read -r ip_address; do
  echo "Send to $ip_address..."
  scp -o StrictHostKeyChecking=no /root/ocm_package/quay.io_open-cluster-management_registration-operator_v0.16.0.tar root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no /root/ocm_package/quay.io_open-cluster-management_registration_v0.16.0.tar root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no /root/ocm_package/quay.io_open-cluster-management_work_v0.16.0.tar root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no -r /root/images_google/ root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no -r /root/images_system/ root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no -r /root/addon/ root@$ip_address:/root/ &
done < "node_ip"

wait

MAX_PARALLEL=50
current_jobs=0

while IFS= read -r ip_address; do
  echo "Import to $ip_address..."
  ssh -o StrictHostKeyChecking=no root@$ip_address bash -c "'
    ctr -n k8s.io images import /root/quay.io_open-cluster-management_registration-operator_v0.16.0.tar  &
    ctr -n k8s.io images import /root/quay.io_open-cluster-management_registration_v0.16.0.tar  &
    ctr -n k8s.io images import /root/quay.io_open-cluster-management_work_v0.16.0.tar  &
    for image in /root/images_google/*.tar; do
      ctr -n k8s.io images import \"\$image\"  &
    done
    for image in /root/images_system/*.tar; do
      ctr -n k8s.io images import \"\$image\"  &
    done
    wait
  '" </dev/null &

  current_jobs=$((current_jobs + 1))

  if [ "$current_jobs" -ge "$MAX_PARALLEL" ]; then
    wait -n
    current_jobs=$((current_jobs - 1))
  fi
done < "node_ip"

wait

echo "All imports done on all nodes!"

cd /root/ocm_package

for image in *.tar *.tar.gz; do
    if [ -f "$image" ]; then
        echo "Importing image: $image"
        ctr -n k8s.io images import "$image"
    fi
done

cd /root/images_system

for image in *.tar *.tar.gz; do
    if [ -f "$image" ]; then
        echo "Importing image: $image"
        ctr -n k8s.io images import "$image"
    fi
done

cd /root/sec2025/federation_framework/scenario1/ocm/

cluster=1
for i in $(cat node_list)
do
	ssh-keyscan $i >> /root/.ssh/known_hosts
	scp /root/.kube/config root@$i:/root/.kube
	ssh root@$i bash /root/sec2025/federation_framework/scenario1/ocm/worker_node.sh $cluster &
	cluster=$((cluster+1))
done

kubectl taint nodes --all node-role.kubernetes.io/control-plane-

for i in `seq 0 0`
do
    kubectl config use-context cluster$i
	  helm repo update
	  helm install cilium cilium/cilium --version 1.17.2 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
    sleep 30
done

sleep 30

echo "-------------------------------------- OK --------------------------------------"