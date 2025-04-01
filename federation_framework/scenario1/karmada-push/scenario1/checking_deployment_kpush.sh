numberofpod=$1
result=$((numberofpod / 10))
NUM_PODS=$result
SLEEP_INTERVAL=1

while true; do
    running_pods=$(kubectl get deployment --context cluster1 --no-headers | wc -l)
    echo "deployment: "$running_pods
    if [ "$running_pods" -eq "$NUM_PODS" ]; then
        current_time=$(date +'%s.%N')
        echo timefordeployment >> number.txt
        echo $current_time >> number.txt
        break
    else
        sleep $SLEEP_INTERVAL
    fi
done