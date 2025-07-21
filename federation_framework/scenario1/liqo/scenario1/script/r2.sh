for ((i=1; i<=2; i++)); do
  export ID=$i
  envsubst < ./script/google_demo.yaml | envsubst < ./script/google_demo.yaml | kubectl delete -n default -f - &
done

echo "finish cleanup timestamps $(date +'%s.%N')" >> number.txt