for ((i=1; i<=2; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "finish cleanup timestamps $(date +'%s.%N')" >> number.txt