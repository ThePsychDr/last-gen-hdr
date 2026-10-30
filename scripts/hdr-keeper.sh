#!/usr/bin/env bash
# Starts, stops or reports the HDR keeper on a Fire TV Cube (3rd gen). The keeper
# (hdr-keeper-device.sh) runs on the Cube and holds the HDR10 InfoFrame on its HDMI output while the
# HDMI IN is on screen in passthrough, so the TV reads the console's picture as HDR10 (PQ).
#
#   start   copy the keeper to /data/local/tmp and start it detached (keeps running if adb drops)
#   stop    ask it to stop, then confirm it's gone; Fire OS puts its own HDR state back
#   status  whether it's running, plus the last lines of its log
#   remove  stop it and delete its files from /data/local/tmp
#
# It writes only to the HDMI-TX driver's config node while running, and to its own files in
# /data/local/tmp. Nothing it writes to the driver survives a reboot of the Cube.
#
# Usage: hdr-keeper.sh <cube-ip>[:port] start|stop|status|remove
#        ADB=/path/to/adb overrides the adb binary (default: adb on PATH)
set -u

usage="usage: hdr-keeper.sh <cube-ip>[:port] start|stop|status|remove"
[ $# -eq 2 ] || { echo "$usage"; exit 2; }
host="$1"
cmd="$2"
here="$(cd "$(dirname "$0")" && pwd)"
payload="$here/hdr-keeper-device.sh"

# Git Bash on Windows rewrites arguments that look like /paths into Windows paths, which would turn
# /data/local/tmp into a folder under the Git install. Turn that off; local paths go through
# cygpath instead.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
localpath() { if command -v cygpath > /dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi; }

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
state="$("$adb" -s "$dev" get-state 2>&1 | tr -d '\r')"
if [ "$state" != device ]; then
    echo "$dev is '$state': accept the \"Allow USB debugging?\" prompt on the TV, then run this again"
    exit 1
fi

ashell() { "$adb" -s "$dev" shell "$@" < /dev/null | tr -d '\r'; }
running() { ashell "pgrep -f hdr-keeper-device.sh"; }

stop_keeper() {
    [ -n "$(running)" ] || { echo "not running"; return; }
    ashell "touch /data/local/tmp/hdr-keeper.stop"
    for _ in 1 2 3 4 5; do [ -z "$(running)" ] && break; sleep 1; done
    if [ -z "$(running)" ]; then echo "stopped"; else ashell "pkill -f hdr-keeper-device.sh"; echo "killed"; fi
}

case "$cmd" in
    start)
        if [ -n "$(running)" ]; then echo "already running"; exit 0; fi
        # grep can't be used here: Git for Windows' grep ignores CRs
        # shellcheck disable=SC2094  # both sides only read the file
        if ! tr -d '\r' < "$payload" | cmp -s - "$payload"; then
            printf '%s\n' "$payload has Windows line endings; re-clone the repo or run: sed -i 's/\r\$//' $payload"
            exit 1
        fi
        "$adb" -s "$dev" push "$(localpath "$payload")" /data/local/tmp/hdr-keeper-device.sh > /dev/null || exit 1
        ashell "setsid nohup sh /data/local/tmp/hdr-keeper-device.sh > /dev/null 2>&1 &"
        sleep 2
        if [ -n "$(running)" ]; then echo "started"; else echo "failed to start"; exit 1; fi
        ;;
    stop)
        stop_keeper
        ;;
    status)
        pids="$(running | tr '\n' ' ')"
        if [ -n "$pids" ]; then echo "running (pid ${pids% })"; else echo "not running"; fi
        ashell "tail -n 5 /data/local/tmp/hdr-keeper.log 2>/dev/null"
        ;;
    remove)
        stop_keeper
        ashell "rm -f /data/local/tmp/hdr-keeper-device.sh /data/local/tmp/hdr-keeper.log /data/local/tmp/hdr-keeper.stop"
        echo "removed the keeper's files; reboot the Cube to be sure Fire OS is back in charge of the output"
        ;;
    *)
        echo "$usage"; exit 2
        ;;
esac
