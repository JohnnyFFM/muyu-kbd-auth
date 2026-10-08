#!/system/bin/sh
# start.sh - run the MiDevAuth HAL daemon + keyboard auth bridge (detached)
cd /data/local/tmp/mda
# one daemon
kill -9 $(pidof midevauthd) 2>/dev/null
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 setsid ./midevauthd >/data/local/tmp/mda/d.log 2>&1 </dev/null &
sleep 5
# one bridge (kill any existing kbd_auth.sh first)
for p in $(ps -A 2>/dev/null | grep kbd_auth | awk "{print \$2}"); do kill -9 $p 2>/dev/null; done
: > /data/adb/kbd/auth.log
setsid ./kbd_auth.sh >/data/local/tmp/mda/run.log 2>&1 </dev/null &
sleep 3
echo "midevauthd=$(pidof midevauthd) vnd=$(vndservice list 2>/dev/null | grep -c midevauth)"
echo "=== auth.log ==="; cat /data/adb/kbd/auth.log
