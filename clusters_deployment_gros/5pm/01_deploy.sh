python3 ./cluster/management.py

echo "wait for 30 secs"
sleep 30

python3 ./cluster/m1.py

echo "wait for 60 secs"
sleep 60

. ./02_system_ready.sh