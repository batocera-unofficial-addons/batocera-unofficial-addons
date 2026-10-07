#!/bin/bash
#
# netwatch service for Batocera.
# Install as /userdata/system/services/netwatch (no extension), make it
# executable, then enable it from EmulationStation (System settings >
# Services) or with `batocera-services enable netwatch`.
#
# Settings live in $NETWATCH_HOME/netwatch.conf, which this script reads on
# every start. Variables set there override the defaults below.

NETWATCH_HOME="${NETWATCH_HOME:-/userdata/system/add-ons/netwatch}"
CONF="$NETWATCH_HOME/netwatch.conf"
PIDFILE="/var/run/netwatch.pid"

# Defaults; netwatch.conf may override any of these.
NETWATCH_ARGS=""
NETWATCH_LOG=""                  # empty means $NETWATCH_HOME/netwatch.log
NETWATCH_LOG_MAX_BYTES=1048576   # rotate once the log reaches this size (1 MB)
NETWATCH_LOG_KEEP=3              # rotated logs to keep: netwatch.log.1 .. .3
NETWATCH_SERVICE_LOG=""          # empty means netwatch-service.log beside NETWATCH_LOG

mkdir -p "$NETWATCH_HOME"
[ -f "$CONF" ] && . "$CONF"
NETWATCH_LOG="${NETWATCH_LOG:-$NETWATCH_HOME/netwatch.log}"
NETWATCH_SERVICE_LOG="${NETWATCH_SERVICE_LOG:-$(dirname "$NETWATCH_LOG")/netwatch-service.log}"

running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

start() {
    if running; then
        echo "netwatch is already running (pid $(cat "$PIDFILE"))"
        return 0
    fi
    if [ ! -f "$NETWATCH_HOME/netwatch.py" ]; then
        echo "netwatch.py not found in $NETWATCH_HOME"
        return 1
    fi
    mkdir -p "$(dirname "$NETWATCH_LOG")" "$(dirname "$NETWATCH_SERVICE_LOG")"
    # netwatch rotates its own log (NETWATCH_LOG) while it runs. The service log
    # only catches restarts and anything printed before netwatch's logging is up
    # (e.g. a syntax error). The loop reopens it on every pass and rolls it to
    # .1 once it passes NETWATCH_LOG_MAX_BYTES, so even a crash loop stays bounded.
    # setsid gives the loop its own process group, so stop can end the loop and
    # python together. The loop restarts netwatch if it exits.
    NETWATCH_HOME="$NETWATCH_HOME" DISPLAY="${DISPLAY:-:0}" NETWATCH_ARGS="$NETWATCH_ARGS" \
    NETWATCH_LOG="$NETWATCH_LOG" NETWATCH_LOG_MAX_BYTES="$NETWATCH_LOG_MAX_BYTES" \
    NETWATCH_LOG_KEEP="$NETWATCH_LOG_KEEP" SLOG="$NETWATCH_SERVICE_LOG" \
    setsid bash -c '
        while true; do
            if [ "$NETWATCH_LOG_MAX_BYTES" -gt 0 ] && [ -f "$SLOG" ] && \
               [ "$(stat -c %s "$SLOG")" -gt "$NETWATCH_LOG_MAX_BYTES" ]; then
                mv -f "$SLOG" "$SLOG.1"
            fi
            python3 "$NETWATCH_HOME/netwatch.py" --no-tui \
                --log-file "$NETWATCH_LOG" --log-max-bytes "$NETWATCH_LOG_MAX_BYTES" \
                --log-keep "$NETWATCH_LOG_KEEP" $NETWATCH_ARGS >>"$SLOG" 2>&1
            rc=$?
            echo "$(date "+%F %T") netwatch exited with status $rc; restarting in 5s" >>"$SLOG"
            sleep 5
        done' >/dev/null 2>&1 < /dev/null &
    echo $! > "$PIDFILE"
    echo "netwatch started (pid $!), log: $NETWATCH_LOG"
}

stop() {
    if running; then
        kill -TERM -- "-$(cat "$PIDFILE")" 2>/dev/null || kill "$(cat "$PIDFILE")"
        rm -f "$PIDFILE"
        echo "netwatch stopped"
    else
        rm -f "$PIDFILE"
        echo "netwatch is not running"
    fi
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)
        if running; then echo "netwatch is running (pid $(cat "$PIDFILE")), log: $NETWATCH_LOG"
        else echo "netwatch is stopped"; exit 1; fi ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac