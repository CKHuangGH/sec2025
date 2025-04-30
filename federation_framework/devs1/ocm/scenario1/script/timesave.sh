#!/bin/bash

# 精確到奈秒的 UNIX timestamp
current_time=$(date +'%s.%N')

# 取得傳入的文字參數
message="$*"

# 寫入 time.txt
echo "$message $current_time" >> time.txt
