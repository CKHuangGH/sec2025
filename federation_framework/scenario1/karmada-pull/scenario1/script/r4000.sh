for ((i=1; i<=400; i++)); do
    kubectl delete deployment nginx-$i  --kubeconfig /etc/karmada/karmada-apiserver.config
done