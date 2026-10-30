# shellcheck shell=sh
# Runs ON the Fire TV Cube (as the adb shell user), started by hdr-keeper.sh. Holds the HDR10
# InfoFrame on the Cube's HDMI output while its HDMI IN is on screen with HDMI Input Passthrough
# (persist.sys.hdmi.passthrough.mode=on).
#
# Fire OS's video path writes SDR back to the HDMI-TX packet about once a frame, so this writes `hdr`
# to the driver's config node back to back, with shell builtins only (no forks): about 9,000 writes/s
# on one CPU core. Checking first and writing every 50 ms held HDR10 in only ~7% of status reads;
# writing back to back held it in ~98%.
#
# Re-checks the passthrough prop every ~0.25 s and idles (one check a second) whenever the input
# isn't on screen, so the Fire TV home screen and apps are left alone.
# Stops when /data/local/tmp/hdr-keeper.stop appears, or after 4 hours.
t=/sys/class/amhdmitx/amhdmitx0
stop=/data/local/tmp/hdr-keeper.stop
log=/data/local/tmp/hdr-keeper.log
rm -f "$stop"
read -r up _ < /proc/uptime
end=$(( ${up%.*} + 14400 ))
active=0
n=0
echo "$(date '+%F %T') start" > "$log"
while [ ! -e "$stop" ]; do
    read -r up _ < /proc/uptime
    [ "${up%.*}" -lt "$end" ] || break
    if [ "$(getprop persist.sys.hdmi.passthrough.mode)" = on ]; then
        if [ "$active" = 0 ]; then
            active=1
            echo "$(date '+%F %T') HDMI IN on screen: holding HDR10" >> "$log"
        fi
        i=0
        while [ "$i" -lt 2000 ]; do echo hdr > "$t/config"; i=$((i + 1)); done
        n=$((n + 2000))
    else
        if [ "$active" = 1 ]; then
            active=0
            echo "$(date '+%F %T') HDMI IN off screen after $n writes: idle" >> "$log"
        fi
        sleep 1
    fi
done
echo "$(date '+%F %T') stop ($n writes)" >> "$log"
