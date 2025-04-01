for ((i=1; i<=1000; i++)); do
    kubectl delete deployment nginx-$i  --kubeconfig /etc/karmada/karmada-apiserver.config
done