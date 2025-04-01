numberofpod=$1
NUM_PODS=$numberofpod
SLEEP_INTERVAL=1

while true; do
    running_pods=$(kubectl get pods --field-selector=status.phase=Running --no-headers --context cluster1 | wc -l)
    echo "pods: "$running_pods
    if [ "$running_pods" -eq "$NUM_PODS" ]; then
        current_time=$(date +'%s.%N')
        echo timeforpods >> number.txt
        echo $current_time >> number.txt
        break
    else
        sleep $SLEEP_INTERVAL
    fi
done