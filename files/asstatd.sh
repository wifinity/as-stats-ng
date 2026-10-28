#!/bin/sh
# Run the AS-Stats collector with listeners chosen by environment variables.
set -eu

netflow_port=0
sflow_port=0
if [ "${NETFLOW:-0}" = 1 ]; then
    netflow_port=${NETFLOW_PORT:-9000}
fi
if [ "${SFLOW:-0}" = 1 ]; then
    sflow_port=${SFLOW_PORT:-6343}
fi

if [ "$netflow_port" = 0 ] && [ "$sflow_port" = 0 ]; then
    echo "asstatd: neither NETFLOW=1 nor SFLOW=1 is set; collector disabled"
    exec tail -f /dev/null
fi

set -- -r /data/as-stats/rrd -k /data/as-stats/conf/knownlinks -p "$netflow_port" -P "$sflow_port"
if [ "$sflow_port" != 0 ]; then
    if [ -z "${SFLOW_ASN:-}" ]; then
        echo "asstatd: SFLOW=1 requires SFLOW_ASN" >&2
        exit 1
    fi
    set -- "$@" -a "$SFLOW_ASN"
fi
if [ "${IPV6:-0}" = 1 ]; then
    set -- "$@" -6
fi

exec /root/AS-Stats/bin/asstatd.pl "$@"
