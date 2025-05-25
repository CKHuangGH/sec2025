for ((i=1; i<=200; i++)); do
    clusteradm delete work test$i --cluster cluster1
done