#!/bin/sh

CADIR="${CONFDIR}/ca"
CAKEYFILE="${CADIR}/ca.key"
CACERTFILE="${CADIR}/ca.crt"

if [ -z "${VPNPORT}" ]; then export VPNPORT=1194; fi

createDH()
{
	if [ -f ${VPNDHFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${VPNDHFILE}`
	openssl dhparam -out ${VPNDHFILE} 2048
}

createTA()
{
	if [ -f ${VPNTAKEYFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${VPNTAKEYFILE}`
	openvpn --genkey secret ${VPNTAKEYFILE}
	sed -i '/#.*$/d' ${VPNTAKEYFILE}
}

createCA()
{
	if [ -f ${CAKEYFILE} ] && [ -f ${CACERTFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${CAKEYFILE}`
	openssl genrsa -out ${CAKEYFILE} 4096

	mkdir -p `dirname ${CACERTFILE}`
	CACONF="${TEMPLATESDIR}/openssl/ca.conf.template"
	envsubst < ${CACONF} | openssl req -config - -x509 -new -nodes -extensions v3_ca -key ${CAKEYFILE} -sha256 -days 3650 -out ${CACERTFILE}
}

createServer()
{
	if [ -f ${VPNCERTFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${VPNCAFILE}`
	cp ${CACERTFILE} ${VPNCAFILE}

	mkdir -p `dirname ${VPNKEYFILE}`
	openssl genrsa -out ${VPNKEYFILE} 4096

	VPNCONF="${TEMPLATESDIR}/openssl/vpn.conf.template"
	VPNCSRFILE="${VPNDIR}/vpn.csr"
	mkdir -p `dirname ${VPNCSRFILE}`
	envsubst < ${VPNCONF} | openssl req -config - -new -key ${VPNKEYFILE} -out ${VPNCSRFILE}
	openssl x509 -req -in ${VPNCSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${VPNCERTFILE} -days 500 -sha256

	createTA
	createDH
}

createServerConfig()
{
	SERVERCONF="${TEMPLATESDIR}/openvpn/server.conf.template"
	VPNPROTO=tcp envsubst < ${SERVERCONF} > ${TCPCONF}
	VPNPROTO=udp envsubst < ${SERVERCONF} > ${UDPCONF}
}

createClient()
{
	CLIENTCONF=${TEMPLATESDIR}/openssl/client.conf.template
	TCPCLIENTCONF=${TEMPLATESDIR}/openvpn/tcp.ovpn.template

	NAME=${CLIENT_CN}

	local DIR="${CLIENTSDIR}/${NAME}"
	local KEYFILE="${DIR}/${NAME}.key"
	local CSRFILE="${DIR}/${NAME}.csr"
	local CERTFILE="${DIR}/${NAME}.crt"

	if [ ! -f ${CERTFILE} ];
	then
		mkdir -p ${DIR}

		openssl genrsa -out ${KEYFILE} 4096
		envsubst < ${CLIENTCONF} | openssl req -config - -new -key ${KEYFILE} -out ${CSRFILE}
		openssl x509 -req -in ${CSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${CERTFILE} -days 365 -sha256
	fi

	export CACERT=`cat $CACERTFILE`
	export CLIENTKEY=`cat $KEYFILE`
	export CLIENTCERT=`cat $CERTFILE`
	export VPNTAKEY=`cat $VPNTAKEYFILE`

	if [ -z "${VPNADDR}" ]; then export VPNADDR=${VPN_CN}; fi

	export CONNECTION1=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto udp\n</connection>\n"`
	export CONNECTION2=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto tcp-client\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto tcp-client\n</connection>\n"`
	export CONNECTION2=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto udp\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-tcp-udp.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto tcp-client\n</connection>\n"`
	export CONNECTION2=""
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-tcp-only.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPNADDR} ${VPNPORT}\nproto udp\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-udp-only.ovpn
}

createCA

createServer

createClient

createServerConfig