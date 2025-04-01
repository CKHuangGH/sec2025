kubectl get pod -A
kubectl get pod -A --context cluster1

cp ../node_list node_list
cp ../node_list_all node_list_all

input_file="node_list_all"
output_file="node_exec"

if [ -f "$input_file" ]; then
    last_line=$(tail -n 1 "$input_file")
    
    echo "$last_line" > "$output_file"
    echo "save to $output_file"
else
    echo "fail to open $input_file"
fi

echo "screen -S mysession"