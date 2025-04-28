python3 ./cluster/management.py

echo "wait for 30 secs"
sleep 30

python3 ./cluster/m1.py &
# python3 ./cluster/m2.py &
# python3 ./cluster/m3.py &
# python3 ./cluster/m4.py &
# python3 ./cluster/m5.py &
# python3 ./cluster/m6.py &
# python3 ./cluster/m7.py &
# python3 ./cluster/m8.py &
# python3 ./cluster/m9.py &
# python3 ./cluster/m10.py &
# python3 ./cluster/m11.py &
# python3 ./cluster/m12.py &
# python3 ./cluster/m13.py &
# python3 ./cluster/m14.py &
# python3 ./cluster/m15.py &
# python3 ./cluster/m16.py &
# python3 ./cluster/m17.py &
# python3 ./cluster/m18.py &
# python3 ./cluster/m19.py &
# python3 ./cluster/m20.py 

echo "wait for 60 secs"
sleep 60

. ./02_system_ready.sh