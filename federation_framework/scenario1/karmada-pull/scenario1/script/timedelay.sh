#!/bin/bash
set -euo pipefail

# === 設定參數 ===
DEV=ens3         # 實體網卡名稱
IFB=ifb0         # 虛擬中介設備
DELAY="50ms"
JITTER="5ms"
LOSS="1%"

# === 啟用 IFB ===
sudo modprobe ifb numifbs=1
ip link show "$IFB" &>/dev/null || sudo ip link add "$IFB" type ifb
sudo ip link set dev "$IFB" up

# === 清除舊設定 ===
sudo tc qdisc del dev "$DEV" root 2>/dev/null || true
sudo tc qdisc del dev "$DEV" clsact 2>/dev/null || true
sudo tc qdisc del dev "$IFB" root 2>/dev/null || true

# === 出站（Egress）設定 ===
echo "⚙️ 設定出站 NetEm（排除 SSH）"
sudo tc qdisc add dev "$DEV" root handle 1: prio bands 3
sudo tc qdisc add dev "$DEV" parent 1:2 handle 20: netem delay $DELAY $JITTER loss $LOSS

# SSH TCP 請求（目標 port 22）→ 不 delay
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 1 u32 \
    match ip protocol 6 0xff \
    match ip dport 22 0xffff \
    flowid 1:1

# SSH TCP 回應（來源 port 22）→ 不 delay
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 2 u32 \
    match ip protocol 6 0xff \
    match ip sport 22 0xffff \
    flowid 1:1

# 其他所有流量 → delay
sudo tc filter add dev "$DEV" protocol ip parent 1: prio 10 u32 \
    match u32 0 0 \
    flowid 1:2

# === 入站（Ingress via IFB）設定 ===
echo "🔄 設定 ingress 重導 + NetEm（排除 SSH）"
sudo tc qdisc add dev "$DEV" clsact
sudo tc filter add dev "$DEV" ingress protocol ip u32 match u32 0 0 \
    action mirred egress redirect dev "$IFB"

sudo tc qdisc add dev "$IFB" root handle 2: prio bands 3
sudo tc qdisc add dev "$IFB" parent 2:2 handle 30: netem delay $DELAY $JITTER loss $LOSS

# SSH TCP 回應（來源 port 22）→ 不 delay
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 1 u32 \
    match ip protocol 6 0xff \
    match ip sport 22 0xffff \
    flowid 2:1

# SSH TCP 請求（目標 port 22）→ 不 delay
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 2 u32 \
    match ip protocol 6 0xff \
    match ip dport 22 0xffff \
    flowid 2:1

# 其他所有流量 → delay
sudo tc filter add dev "$IFB" protocol ip parent 2: prio 10 u32 \
    match u32 0 0 \
    flowid 2:2

echo "✅ NetEm 完成設定：除了 SSH，其餘流量皆加 delay/loss"

# Optional: 測試
while read -r ip; do
    if [[ "$ip" =~ ^[[:space:]]*$ || "$ip" =~ ^\s*# ]]; then
        continue
    fi
    ping -c 4 "$ip"
    break
done < "node_list"