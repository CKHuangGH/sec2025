for ((i=1; i<=1000; i++)); do
    clusteradm delete work test$i --cluster cluster1
done