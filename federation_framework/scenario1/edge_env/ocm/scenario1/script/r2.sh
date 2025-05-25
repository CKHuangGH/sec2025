for ((i=1; i<=2; i++)); do
	clusteradm delete work demo$i --cluster cluster1 &
done

echo "finish cleanup timestamps $(date +'%s.%N')" >> number.txt