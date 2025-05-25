#!/bin/bash
set -euo pipefail

DEV=ens3
IFB=ifb0
DELAY="50ms"
JITTER="5ms"
LOSS="5%"

# Step 1: 建立並啟用 IFB
sudo modprobe ifb numifbs=1
ip link show "$IFB" &>/dev/null || sudo ip link add "$IFB" type ifb
sudo ip link set dev "$IFB" up

# Step 2: 清除舊設定
sudo tc qdisc del dev "$DEV" root 2>/dev/null || true
sudo tc qdisc del dev "$DEV" clsact 2>/dev/null || true
sudo tc qdisc del dev "$IFB" root 2>/dev/null || true

# Step 3: 套用出站 netem
echo "⚙️  Adding egress netem to $DEV"
sudo tc qdisc add dev "$DEV" root handle 1: netem delay $DELAY $JITTER loss $LOSS

# Step 4: 使用 clsact 做 ingress → ifb0 重導
echo "🔄 Setting up clsact for ingress redirection"
sudo tc qdisc add dev "$DEV" clsact
sudo tc filter add dev "$DEV" ingress protocol ip u32 match u32 0 0 \
    action mirred egress redirect dev "$IFB"

# Step 5: ifb 上加 netem
echo "⚙️  Adding netem to $IFB"
sudo tc qdisc add dev "$IFB" root handle 2: netem delay $DELAY $JITTER loss $LOSS

echo "✅ delay/loss 模擬成功套用 (egress + ingress via ifb)"


while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 4 "$ip"
    break
done < "node_list"