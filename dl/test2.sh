#!/system/bin/sh
cd /data/local/tmp/mda
logcat -c
rm -f d.log
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
sleep 5
echo "alive=$(kill -0 $DP 2>/dev/null && echo y || echo n) pid=$DP"
echo "=== wchan ==="; cat /proc/$DP/wchan 2>/dev/null; echo
echo "=== daemon logcat ==="; logcat -d 2>/dev/null | grep -iE "midevauth|QSEECOM|smcinvoke|devauth|DMABUF|avc: denied" | tail -25
echo "=== service ==="; service list 2>/dev/null | grep -i midevauth || echo NOT_REGISTERED
kill -9 $DP 2>/dev/null
