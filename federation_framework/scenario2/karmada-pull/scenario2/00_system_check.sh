cp ../node_list node_list
cp ../node_list_all node_list_all

for i in $(cat node_list)
do
    ssh root@$i kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
done

sleep 5

kubectl get pod -A
kubectl get pod -A --context cluster1

echo "screen -S mysession"