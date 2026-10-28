#!/bin/sh
# Rebuild the top-AS tables the web UI reads.
# Usage: stats-update [day|week|month ...]   (default: all three)
set -eu

data=/data/as-stats

[ $# -gt 0 ] || set -- day week month
for period in "$@"; do
    case $period in
        day) hours=24 ;;
        week) hours=168 ;;
        month) hours=720 ;;
        *) echo "stats-update: unknown period '$period'" >&2; exit 1 ;;
    esac
    /root/AS-Stats/bin/rrd-extractstats.pl "$data/rrd" "$data/conf/knownlinks" \
        "$data/asstats_$period.txt" "$hours"
done
