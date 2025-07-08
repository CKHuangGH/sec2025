#!/bin/bash

# 取得 join 指令 (去除 <cluster_name> 參數)
token_line=$(clusteradm get token | grep "clusteradm join")
join_cmd=$(echo "$token_line" | sed 's/--cluster-name <cluster_name>//')

echo "取得的 join 指令為："
echo "$join_cmd"
echo "========================================"

# 定義一個函數來處理單一 Node 的 join 動作
register_node() {
  local node_ip="$1"
  local cluster_name="$2"
  
  echo "========================================"
  echo "開始處理 Node IP: $node_ip"
  echo "將命名為叢集：$cluster_name"
  echo "----------------------------------------"

  # 使用失敗重試機制，直到成功為止
  while true; do
    # 執行 join 指令 (加上 --wait 參數)，ssh 的 -n 避免與迴圈 stdin 衝突
    output=$(ssh -n root@"$node_ip" "${join_cmd} --wait --cluster-name $cluster_name" 2>&1)
    ret=$?

    echo "$output"

    # 檢查執行結果：exit code 為 0 且不包含特定錯誤訊息
    if [[ $ret -eq 0 && "$output" != *"Error: unexpected watch event received"* ]]; then
      echo ">>> 加入叢集成功：$cluster_name on $node_ip"
      break
    else
      echo ">>> 加入叢集失敗 (node: $node_ip)。5 秒後重試..."
      sleep 5
    fi
  done
}

# 讀取 node_list 檔案，每一行代表一個 Node 的 IP
i=1
while read -r node_ip; do
  # 跳過空行或被 '#' 註解的行
  [[ -z "$node_ip" || "$node_ip" =~ ^#.* ]] && continue

  # 自動產生 cluster name (cluster1, cluster2, …)
  cluster_name="cluster${i}"
  
  # 在背景中執行每個節點的 join 註冊
  register_node "$node_ip" "$cluster_name" &
  
  i=$((i + 1))
done < "node_list"

# 等待所有背景程序完成
wait
sleep 60
echo "========================================"
echo "全部節點處理完畢！"
