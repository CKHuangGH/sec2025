for ((i=1; i<=800; i++)); do
  export ID=$i
  envsubst < google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done