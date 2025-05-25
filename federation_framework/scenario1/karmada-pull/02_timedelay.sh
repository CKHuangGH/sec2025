#!/bin/bash
set -euo pipefail

DEV=ens3
IFB=ifb0
DELAY="50ms"
JITTER="5ms"
LOSS="5%"

# Step 1: 啟用 IFB 裝置
sudo modprobe ifb numifbs=1
ip link show "$IFB" &>/dev/null || sudo ip link add "$IFB" type ifb
sudo ip link set dev "$IFB" up

# Step 2: 清除現有 tc 設定
sudo tc qdisc del dev "$DEV" root 2>/dev/null || true
sudo tc qdisc del dev "$DEV" clsact 2>/dev/null || true
sudo tc qdisc del dev "$IFB" root 2>/dev/null || true

# Step 3: 出站（Egress）處理
echo "⚙️ 設定出站 netem，排除 SSH 流量"

# 使用 prio 分流：band 1 = SSH，band 2 = others
sudo tc qdisc add dev "$DEV" root handle 1: prio bands 3
sudo tc qdisc add dev "$DEV" parent 1:2 handle 20: netem delay $DELAY $JITTER loss $LOSS

# SSH 流量：目標 port 22 → band 1（不 delay）
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 1 u32 \
    match ip protocol 6 0xff \
    match ip dport 22 0xffff \
    flowid 1:1

# SSH 回應流量：來源 port 22 → band 1（不 delay）
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 2 u32 \
    match ip protocol 6 0xff \
    match ip sport 22 0xffff \
    flowid 1:1

# 其餘 TCP 流量 → band 2（加 delay）
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 3 u32 \
    match ip protocol 6 0xff \
    flowid 1:2

# Step 4: 入站（Ingress） via IFB
echo "🔄 設定 ingress 重導 + 排除 SSH 流量"

# 把 ingress 重導到 IFB
sudo tc qdisc add dev "$DEV" clsact
sudo tc filter add dev "$DEV" ingress protocol ip u32 match u32 0 0 \
    action mirred egress redirect dev "$IFB"

# IFB 上的 prio + netem
sudo tc qdisc add dev "$IFB" root handle 2: prio bands 3
sudo tc qdisc add dev "$IFB" parent 2:2 handle 30: netem delay $DELAY $JITTER loss $LOSS

# 入站封包：來源 port 22（SSH server 回應） → band 1（不 delay）
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 1 u32 \
    match ip protocol 6 0xff \
    match ip sport 22 0xffff \
    flowid 2:1

# 入站封包：目標 port 22（client 請求） → band 1（不 delay）
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 2 u32 \
    match ip protocol 6 0xff \
    match ip dport 22 0xffff \
    flowid 2:1

# 其他 TCP 流量 → band 2（加 delay）
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 3 u32 \
    match ip protocol 6 0xff \
    flowid 2:2

echo "✅ NetEm 已套用（SSH 完全排除 delay/loss）"

# Optional: 測試
while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 4 "$ip"
    break
done < "node_list"