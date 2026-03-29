#!/usr/bin/env bash
set -euo pipefail

LIMIT="${1:-30}"

ps -eo pid=,ppid=,user=,comm=,%mem=,rss=,args= --sort=-rss | \
head -n "$LIMIT" | \
awk -v limit="$LIMIT" '
function human(kib, mib, gib) {
    mib = kib / 1024
    gib = mib / 1024
    if (gib >= 1) return sprintf("%.2f GiB", gib)
    return sprintf("%.1f MiB", mib)
}
function short(text, maxlen) {
    return length(text) > maxlen ? substr(text, 1, maxlen - 3) "..." : text
}
function extra(proc, cmd, m) {
    if (proc ~ /^qemu-system/ && match(cmd, /guest=([^,[:space:]]+)/, m)) return "VM:" m[1]
    if (proc == "php-fpm" && match(cmd, /pool ([^ ]+)/, m)) return "PHP-Pool:" m[1]
    return "-"
}
BEGIN {
    printf "\nTop %d RAM-Fresser (sortiert nach RSS)\n\n", limit
    printf "%-6s %-6s %-14s %-22s %-8s %-10s %-20s %s\n", \
           "PID", "PPID", "USER", "PROCESS", "%MEM", "RSS", "INFO", "COMMAND"
    printf "%s\n", \
           "--------------------------------------------------------------------------------------------------------------------------------"
}
{
    pid  = $1
    ppid = $2
    user = $3
    proc = $4
    mem  = $5
    rss  = $6

    cmd = $0
    for (i = 1; i <= 6; i++) {
        sub(/^[^[:space:]]+[[:space:]]+/, "", cmd)
    }

    printf "%-6s %-6s %-14s %-22s %-8s %-10s %-20s %s\n", \
           pid, ppid, user, short(proc, 22), mem "%", human(rss), short(extra(proc, cmd), 20), short(cmd, 90)
}
'
