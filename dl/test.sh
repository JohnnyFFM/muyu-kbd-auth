#!/system/bin/sh
cd /data/local/tmp/mda
rm -f d.log
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
sleep 4
echo "DP=$DP alive=$(kill -0 $DP 2>/dev/null && echo y || echo n)"
echo "=== service_list ==="; service list 2>/dev/null | grep -i midevauth || echo NOT_REGISTERED
echo "=== keyver ==="; timeout 15 ./tokenhelper keyver; echo "rc=$?"
echo "=== offlinecheck ==="; timeout 15 ./tokenhelper offlinecheck "00 00 00 02"; echo "rc=$?"
echo "=== token ==="; timeout 15 ./tokenhelper token 1 "00 07 00 01 00 00 00 00 00 19 78 93 d8 82 6e 50" "00 00 00 02" "43 19 e2 89 49 49 00 01 04 11 12 13 27 76 01 32"; echo "rc=$?"
echo "=== d.log ==="; tail -10 d.log
kill -9 $DP 2>/dev/null
