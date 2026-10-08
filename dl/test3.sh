#!/system/bin/sh
cd /data/local/tmp/mda
logcat -c
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
i=0
while [ $i -lt 12 ]; do
  sleep 2; i=$((i+1))
  if service list 2>/dev/null | grep -qi midevauth; then echo "REGISTERED at ~$((i*2))s"; break; fi
  echo "t=$((i*2))s not yet (alive=$(kill -0 $DP 2>/dev/null && echo y || echo n))"
done
echo "=== final service check ==="; service list 2>/dev/null | grep -i midevauth || echo STILL_NOT_REGISTERED
echo "=== last daemon logcat line ==="; logcat -d 2>/dev/null | grep -iE "midevauth|BackendUnified|addService|registerLazy|key version" | tail -8
echo "=== tokenhelper keyver ==="; timeout 12 ./tokenhelper keyver; echo "rc=$?"
kill -9 $DP 2>/dev/null
