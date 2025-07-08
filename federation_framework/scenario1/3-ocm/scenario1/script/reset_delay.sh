#!/bin/bash
set -euo pipefail

# === 設定參數 ===
DEV=ens3         # 實體網卡名稱
IFB=ifb0         # 虛擬中介設備

echo "🧹 清除 NetEm 與 IFB 設定..."

# === 移除所有 tc 規則與佇列 ===
sudo tc qdisc del dev "$DEV" root 2>/dev/null || true
sudo tc qdisc del dev "$DEV" clsact 2>/dev/null || true
sudo tc qdisc del dev "$IFB" root 2>/dev/null || true

# === 移除 IFB 裝置 ===
if ip link show "$IFB" &>/dev/null; then
    sudo ip link set dev "$IFB" down
    sudo ip link delete "$IFB" type ifb
    echo "🗑️ IFB $IFB 已刪除"
fi

echo "✅ 所有 NetEm 設定已重設為預設狀態"