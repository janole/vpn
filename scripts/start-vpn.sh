#!/bin/sh

set -e

openssl verify -verbose -CAfile ${VPNCAFILE} ${VPNCERTFILE}

CONF="${SERVERCONF:-$TCPCONF}"

VPN_PORT=`grep "^port " $CONF | sed -e "s/[^0-9]*//g"`
envsubst < /etc/iptables/rules.v4 | iptables-restore

echo "Starting with config ${CONF} ..."
exec openvpn --config ${CONF}
