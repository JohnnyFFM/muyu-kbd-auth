#!/system/bin/sh
cd /data/local/tmp/mda
kill -9 $(pidof midevauthd) 2>/dev/null
LD_LIBRARY_PATH=/data/local/tmp/mda:/vendor/lib64:/system/lib64 ./midevauthd >d.log 2>&1 &
DP=$!
sleep 5
: > /data/adb/kbd/auth.log
./kbd_auth.sh >run.log 2>&1 &
KP=$!
UP0=$(cut -d" " -f1 /proc/uptime)
sleep 45
UP1=$(cut -d" " -f1 /proc/uptime)
echo "watched ${UP0}..${UP1}"
echo "=== auth.log ==="; cat /data/adb/kbd/auth.log
echo "=== counts: step5=$(grep -c "STEP5 sent" /data/adb/kbd/auth.log) tokenfail=$(grep -c "token_get FAILED" /data/adb/kbd/auth.log) ==="
echo "=== sniffer: keyboard-initiated REQUEST_REAUTH in window ==="; grep REQUEST_REAUTH /data/adb/kbd/packets.log 2>/dev/null | tail -6
echo "=== sniffer last 6 pkts (is keyboard alive, not stalled?) ==="; tail -6 /data/adb/kbd/packets.log 2>/dev/null | cut -c1-55
echo "=== kbd status ==="; cat /sys/class/nanodev/nanodev0/_version176x 2>/dev/null | head -1
kill -9 $KP $DP 2>/dev/null
