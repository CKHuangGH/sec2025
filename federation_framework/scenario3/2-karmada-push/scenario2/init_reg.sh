#!/bin/bash

# 檢查是否有傳入預期集群數量參數
if [ $# -lt 1 ]; then
    echo "Usage: $0 <expected_cluster_count>"
    exit 1
fi

expected_count=$1

# 設定 kubeconfig context 及初始化 karmada
kubectl config use-context cluster0
kubectl karmada init

# 不斷執行註冊，直到集群數量達到指定數量
while true; do
    echo "開始執行節點註冊..."
    cluster=1
    for i in $(cat node_list)
    do
        kubectl karmada --kubeconfig /etc/karmada/karmada-apiserver.config join cluster$cluster --cluster-kubeconfig=$HOME/.kube/cluster$cluster &
        cluster=$((cluster+1))
    done

    # 等待一段時間讓註冊動作完成
    wait

    # 取得目前集群數量
# 取得目前已存在的所有 Karmada Clusters 總數
    current_count=$(kubectl get clusters \
        --kubeconfig /etc/karmada/karmada-apiserver.config \
        --no-headers 2>/dev/null | wc -l)

    echo "目前已註冊集群數量：$current_count"

    # 判斷數量是否達到預期
    if [ "$current_count" -ge "$expected_count" ]; then
        echo "集群數量達到預期 ($expected_count)，進行狀態檢查..."

        # 檢查所有 Cluster 是否都為 Ready = True
        all_ready=true
        # 取得所有 Cluster 名稱
        cluster_list=$(kubectl get clusters \
            --kubeconfig /etc/karmada/karmada-apiserver.config \
            --no-headers | awk '{print $1}')

        for cl in $cluster_list; do
            # 取得該 Cluster 的 Ready 狀態
            ready_status=$(kubectl get cluster "$cl" \
                --kubeconfig /etc/karmada/karmada-apiserver.config \
                -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

            if [ "$ready_status" != "True" ]; then
                echo "[警告] Cluster $cl 尚未 Ready，當前狀態: $ready_status"
                all_ready=false
                break
            fi
        done

        # 若全部皆為 Ready，則完成
        if [ "$all_ready" = true ]; then
            echo "所有已註冊的 Cluster 均為 Ready 狀態，註冊程序完成。"
            break
        else
            echo "部分 Cluster 尚未就緒，將重新執行註冊..."
        fi
    else
        echo "集群數量不足 (預期 $expected_count, 實際 $current_count)，將重新執行註冊..."
    fi

    # 適度等待再重試（避免太頻繁呼叫）
    sleep 5
done