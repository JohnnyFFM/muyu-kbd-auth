#!/system/bin/sh
cd /data/local/tmp/mda
kill -9 $(pidof midevauthd) 2>/dev/null
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
sleep 5
echo "daemon_vnd=$(vndservice list 2>/dev/null | grep -c midevauth)"
: > /data/adb/kbd/auth.log
./kbd_auth.sh >/data/local/tmp/mda/run.log 2>&1 &
KP=$!
i=0
while [ $i -lt 20 ]; do
  sleep 2; i=$((i+1))
  grep -q "STEP5 sent" /data/adb/kbd/auth.log 2>/dev/null && { echo "*** STEP5 SENT ~$((i*2))s ***"; sleep 3; break; }
done
echo "=== auth.log ==="; tail -24 /data/adb/kbd/auth.log 2>/dev/null
echo "=== keyboard status ==="; cat /sys/class/nanodev/nanodev0/_version176x 2>/dev/null | head -1
kill -9 $KP $DP 2>/dev/null
