for ((i=1; i<=600; i++)); do
    clusteradm delete work test$i --cluster cluster1
done