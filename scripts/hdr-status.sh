#!/usr/bin/env bash
# Read-only: what the Fire TV Cube is sending over HDMI right now, as one line. Changes nothing.
#
#   ready     1 when the output is live; with 0 (Cube asleep) the other driver fields are stale
#   hpd/hdcp  hotplug and HDCP state (22 / 14 / off); a drop means the link re-synced
#   HDR       the driver's HDR state, e.g. HDR10-GAMMA_ST2084 or SDR
#   attr      colour format and bit depth, e.g. rgb,12bit
#   mode      output mode, plus ALLM and content type
#   settings  Dynamic Range (range), Color Depth (depth), HDMI Input Passthrough (setting/active),
#             low-latency mode (ll)
#
# With an interval it keeps sampling and prints a line only when something changes, which is handy
# for watching what a game, an input switch or a setting does to the output (Ctrl+C to stop).
#
# Usage: hdr-status.sh <cube-ip>[:port] [interval-seconds]
#        ADB=/path/to/adb overrides the adb binary (default: adb on PATH)
set -u

usage="usage: hdr-status.sh <cube-ip>[:port] [interval-seconds]"
[ $# -ge 1 ] || { echo "$usage"; exit 2; }
host="$1"
every="${2:-}"

# Stop Git Bash on Windows from rewriting /sys/... arguments into Windows paths.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'

adb="${ADB:-$(command -v adb || command -v adb.exe || true)}"
if [ -z "$adb" ] || [ ! -x "$adb" ]; then
    echo "adb not found: install Android platform-tools or set ADB=/path/to/adb"; exit 1
fi
case "$host" in *:*) dev="$host" ;; *) dev="$host:5555" ;; esac
out="$("$adb" connect "$dev" 2>&1)"
case "$out" in
    *"connected to"*) ;;
    *) echo "could not connect to $dev: $out"; exit 1 ;;
esac

# Some driver nodes end in "\n\r", which command substitution doesn't strip, so v() drops both.
# stdin from /dev/null: otherwise adb shell eats the rest of a script piped to bash.
sample() {
    # shellcheck disable=SC2016  # expanded on the Cube, not here
    "$adb" -s "$dev" shell '
        t=/sys/class/amhdmitx/amhdmitx0
        v() { tr -d "\r\n" < $t/$1; }
        echo "ready=$(v ready) hpd=$(v hpd_state) hdcp=$(v hdcp_mode) | $(v hdmi_hdr_status) | $(v attr)" \
            "| $(grep -m1 "^name:" $t/disp_mode | cut -d" " -f2)" \
            "frac=$(grep -m1 "^frac:" $t/disp_mode | cut -d" " -f2)" \
            "| allm=$(v allm_mode) type=$(v contenttype_mode)" \
            "| range=$(getprop persist.sys.hdmi.hdr.enable) depth=$(getprop persist.sys.open.deepcolor)" \
            "passthrough=$(getprop persist.sys.hdmi.passthrough)/$(getprop persist.sys.hdmi.passthrough.mode)" \
            "ll=$(getprop persist.sys.hdmi.ll.mode)"
    ' < /dev/null | tr -d '\r'
}

if [ -z "$every" ]; then
    sample
    exit
fi

last=""
while :; do
    now="$(sample)"
    if [ "$now" != "$last" ]; then
        echo "$(date +%H:%M:%S) $now"
        last="$now"
    fi
    sleep "$every"
done
