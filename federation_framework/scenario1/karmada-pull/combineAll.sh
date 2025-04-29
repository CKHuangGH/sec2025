number=$1

mkdir /var/log/ntpsec
sudo systemctl stop ntp
sudo ntpd -gq
sudo systemctl start ntp
pip3 install kubernetes --break-system-packages
sudo apt install tcpdump -y

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

while read line
do 
echo $line
ip1=$(echo $line | cut -d "." -f 2)
ip2=$(echo $line | cut -d "." -f 3)
break
done < node_list_all

kubectl taint nodes --all node-role.kubernetes.io/control-plane-

ip=$(cat node_list)

> node_ip
for i in {1..5}; do
  new_ip=$(echo "$ip" | sed "s/\.[0-9]*$/.${i}/")
  echo "$new_ip" >> node_ip
done

while IFS= read -r ip_address; do
  echo "Send to $ip_address..."
  scp -o StrictHostKeyChecking=no /root/karmada_package/docker.io_karmada_karmada-agent_v1.13.1.tar root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no -r /root/images_google/ root@$ip_address:/root/ &
  scp -o StrictHostKeyChecking=no -r /root/images_system/ root@$ip_address:/root/ &
done < "node_ip"

wait

MAX_PARALLEL=50
current_jobs=0

while IFS= read -r ip_address; do
  echo "Import to $ip_address..."
  ssh -o StrictHostKeyChecking=no root@$ip_address bash -c "'
    ctr -n k8s.io images import /root/docker.io_karmada_karmada-agent_v1.13.1.tar  &
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

cd /root/karmada_package

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

cd /root/sec2025/federation_framework/scenario1/karmada-pull/

cluster=1
for i in $(cat node_list)
do
	ssh-keyscan $i >> /root/.ssh/known_hosts
	scp /root/.kube/config root@$i:/root/.kube
	ssh root@$i sh /root/sec2025/federation_framework/scenario1/karmada-pull/worker_node.sh $cluster &
	cluster=$((cluster+1))
done

for i in `seq 0 0`
do
    kubectl config use-context cluster$i
	  helm repo update
	  helm install cilium cilium/cilium --version 1.17.2 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
    sleep 30
    kubectl create ns monitoring
    helm install --version 70.4.2 prometheus-community/kube-prometheus-stack --generate-name --set grafana.enabled=false --set alertmanager.enabled=false --set prometheus.service.type=NodePort --set prometheus.prometheusSpec.scrapeInterval="5s" --set prometheus.prometheusSpec.enableAdminAPI=true --namespace monitoring --values values.yaml --set prometheus.prometheusSpec.resources.requests.cpu="250m" --set prometheus.prometheusSpec.resources.requests.memory="512Mi"
done

sleep 30

echo "-------------------------------------- OK --------------------------------------"