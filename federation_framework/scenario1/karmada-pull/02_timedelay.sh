sudo modprobe ifb

sudo ip link set dev ifb0 up

sudo tc qdisc add dev ens3 root netem delay 50ms 5ms loss 5%

sudo tc qdisc add dev ens3 ingress
sudo tc filter add dev ens3 parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0

sudo tc qdisc add dev ifb0 root netem delay 50ms 5ms loss 5%

echo "delay and loss ok"

while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 4 "$ip"
    break
done < "node_list"