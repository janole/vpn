#!/bin/sh

set -e

openssl verify -verbose -CAfile ${VPNCAFILE} ${VPNCERTFILE}

iptables-restore < /etc/iptables/rules.v4

echo "Starting with config ${SERVERCONF:-$TCPCONF} ..."

exec openvpn --config ${SERVERCONF:-$TCPCONF}
