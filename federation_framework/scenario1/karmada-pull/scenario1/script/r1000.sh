for ((i=1; i<=1000; i++)); do
  export ID=$i
  envsubst < google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "All $i deployments deleted." >> number.txt
date +'%s.%N' >> number.txt