#!/bin/sh

set -e

openssl verify -verbose -CAfile ${VPNCAFILE} ${VPNCERTFILE}

CONF="${SERVERCONF:-$TCPCONF}"

VPN_PORT=`grep "^port " $CONF | sed -e "s/[^0-9]*//g"`
envsubst < $TEMPLATESDIR/openvpn/rules.v4.template | iptables-restore

echo "Starting with config ${CONF} ..."
exec openvpn --config ${CONF}
