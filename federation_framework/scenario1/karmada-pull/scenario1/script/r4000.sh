for ((i=1; i<=400; i++)); do
  export ID=$i
  envsubst < google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done