#!/bin/bash

current_time=$(date +'%s.%N')

message="$*"

echo "$message $current_time" >> time.txt
