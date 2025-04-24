for ((i=1; i<=400; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | kubectl delete --kubeconfig /etc/karmada/karmada-apiserver.config -f -
done

echo "cleanup timestamps $(date +'%s.%N')" >> number.txt