for ((i=1; i<=2; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "All $i deployments deleted." >> number.txt
date +'%s.%N' >> number.txt