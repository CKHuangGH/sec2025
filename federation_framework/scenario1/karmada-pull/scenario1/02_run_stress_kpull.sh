number=$1

while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 2 "$ip" > number.txt
done < "node_list"

echo $number
echo $number >> number.txt
echo "start deployment" >> number.txt
echo $(date +'%s.%N') >> number.txt
. ./script/$number.sh > /dev/null 2>&1

echo "wait for 900 secs"
for (( i=900; i>0; i-- )); do
    echo -ne "\r$i secs remaining..."
    sleep 1
done