#!/bin/sh
# Prepare the data volume and timezone, then hand over to the main process.
set -eu

data=/data/as-stats

tz=${TZ:-UTC}
if [ -f "/usr/share/zoneinfo/$tz" ]; then
    cp "/usr/share/zoneinfo/$tz" /etc/localtime
    echo "$tz" > /etc/timezone
else
    echo "entrypoint: unknown TZ '$tz', using UTC" >&2
fi

mkdir -p "$data/rrd" "$data/conf"
if [ ! -f "$data/conf/knownlinks" ]; then
    echo "entrypoint: $data/conf/knownlinks is missing; the collector and web UI need it" >&2
fi

# The web UI config lives in the volume so edits survive upgrades.
if [ ! -f "$data/config.inc" ]; then
    cp /usr/share/as-stats/config.inc "$data/config.inc"
fi
ln -sf "$data/config.inc" /var/www/config.inc

exec "$@"
