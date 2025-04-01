for ((i=1; i<=800; i++)); do
    clusteradm delete work test$i --cluster cluster1
done