cp node_list node_list_all
sed -i '1d' node_list
ls /root/.kube/
echo $(( $(ls -1 /root/.kube/ | wc -l) - 2 ))
read -p "please enter the last cluster number in .kube: " number

./patch.sh

./combineAll.sh $number