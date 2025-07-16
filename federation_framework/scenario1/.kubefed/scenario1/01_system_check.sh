kubectl get pod -A --field-selector=status.phase!=Running
kubectl get pod -A --context cluster1 --field-selector=status.phase!=Running

cp ../node_list node_list
cp ../node_list_all node_list_all

cp ../node_list ./script/node_list
cp ../node_list_all ./script/node_list_all

input_file="node_list_all"
output_file="node_exec"

if [ -f "$input_file" ]; then
    last_line=$(tail -n 1 "$input_file")
    
    echo "$last_line" > "$output_file"
    echo "save to $output_file"
else
    echo "fail to open $input_file"
fi

cp node_exec ./script/node_exec

echo "screen -S mysession"