number=$1

sudo rm -rf /usr/bin/kubectl

sudo curl -LO https://dl.k8s.io/release/v1.32.1/bin/linux/amd64/kubectl

sudo install -o root -g root -m 0755 kubectl /usr/bin/kubectl

curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

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

sleep 2

while read line
do 
echo $line
ip1=$(echo $line | cut -d "." -f 2)
ip2=$(echo $line | cut -d "." -f 3)
break
done < node_list_all

kubectl taint nodes --all node-role.kubernetes.io/control-plane-

cluster=1
for i in $(cat node_list)
do
	ssh-keyscan $i >> /root/.ssh/known_hosts
	scp /root/.kube/config root@$i:/root/.kube
	ssh root@$i chmod 777 /root/edgesys-2025/federation_framework/scenario1/ocm/worker_node.sh
	ssh root@$i sh /root/edgesys-2025/federation_framework/scenario1/ocm/worker_node.sh $cluster &
	cluster=$((cluster+1))
done

apt-get update
sudo apt-get install vim -y
sudo apt-get install net-tools -y
sudo apt install python3-pip -y
sudo apt-get install jq -y
sudo apt install git -y
sudo apt install ntpdate -y
sudo service ntp stop
sudo ntpdate ntp.midway.ovh
sudo service ntp start
sudo apt install screen -y

# Install helm3
echo "Helm3"
wget -c https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz
tar xzvf helm-v3.8.2-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/
helm repo add stable https://charts.helm.sh/stable
helm repo add cilium https://helm.cilium.io/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "install go"
wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz
cp /usr/local/go/bin/go /usr/local/bin

for i in `seq 0 0`
do
    kubectl config use-context cluster$i
	helm repo update
	helm install cilium cilium/cilium --version 1.13.4 --wait --wait-for-jobs --namespace kube-system --set operator.replicas=1
done

for i in `seq 0 0`
do
  kubectl --context=cluster$i create -f metrics_server.yaml
done
sleep 5

# 讀取初始 node ip (例如 10.10.10.1)
ip=$(cat node_list)

# 生成 node_ip 檔案，依據原始 IP 的前三段，替換最後一段為 1 到 101
> node_ip  # 先清空 node_ip 檔案
for i in {1..101}; do
  new_ip=$(echo "$ip" | sed "s/\.[0-9]*$/.${i}/")
  echo "$new_ip" >> node_ip
done

# 傳送 tar 檔到各個節點
while IFS= read -r ip_address; do
  echo "傳送檔案到 $ip_address ..."
  scp -o StrictHostKeyChecking=no /root/nginx.tar root@$ip_address:/root/
done < "node_ip"

while IFS= read -r ip_address; do
  echo "傳送檔案到 $ip_address ..."
  ssh -o StrictHostKeyChecking=no root@$ip_address "ctr -n k8s.io images import /root/nginx.tar" </dev/null &
done < "node_ip"

echo "-------------------------------------- OK --------------------------------------"