#!/system/bin/sh
cd /data/local/tmp/mda
echo "enforce=$(getenforce)"
logcat -c
setenforce 0
echo "set enforce=$(getenforce)"
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
sleep 5
echo "=== service list (permissive) ==="; service list 2>/dev/null | grep -i midevauth || echo NOT_REGISTERED
echo "=== vndservice ==="; vndservice list 2>/dev/null | grep -i midevauth || echo NO_VND
echo "=== avc denied (midevauth/add) ==="; logcat -d 2>/dev/null | grep -i "avc: denied" | grep -iE "midevauth|add to service|find" | tail -6
echo "=== keyver ==="; timeout 12 ./tokenhelper keyver; echo "rc=$?"
echo "=== token ==="; timeout 15 ./tokenhelper token 1 "00 07 00 01 00 00 00 00 00 19 78 93 d8 82 6e 50" "00 00 00 02" "43 19 e2 89 49 49 00 01 04 11 12 13 27 76 01 32"; echo "rc=$?"
kill -9 $DP 2>/dev/null
setenforce 1
echo "restored enforce=$(getenforce)"
