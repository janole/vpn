#!/bin/sh

CADIR="${CONFDIR}/ca"
CAKEYFILE="${CADIR}/private/ca.key"
CACERTFILE="${CADIR}/public/ca.crt"

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

	CACONF="${TEMPLATESDIR}/ca.conf.template"
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

	VPNCONF="${TEMPLATESDIR}/vpn.conf.template"
	VPNCSRFILE="${VPNDIR}/vpn.csr"
	mkdir -p `dirname ${VPNCSRFILE}`
	envsubst < ${VPNCONF} | openssl req -config - -new -key ${VPNKEYFILE} -out ${VPNCSRFILE}
	openssl x509 -req -in ${VPNCSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${VPNCERTFILE} -days 500 -sha256

	createTA
	createDH

	# openssl verify -verbose -CAfile ${CACERTFILE} ${VPNCERTFILE}
}

createServerConfig()
{
	SERVERCONF="${TEMPLATESDIR}/server.conf.template"
	VPNPROTO=tcp envsubst < ${SERVERCONF} > ${TCPCONF}
	VPNPROTO=udp envsubst < ${SERVERCONF} > ${UDPCONF}
}

createClient()
{
	CLIENTCONF=${TEMPLATESDIR}/client.conf.template
	TCPCLIENTCONF=${TEMPLATESDIR}/tcp.ovpn.template

	NAME=${CLIENT_CN}

	local DIR="${CLIENTSDIR}/${NAME}"
	local KEYFILE="${DIR}/${NAME}.key"
	local CSRFILE="${DIR}/${NAME}.csr"
	local CERTFILE="${DIR}/${NAME}.crt"

	if [ -f ${CERTFILE} ];
	then
		return
	fi

	mkdir -p ${DIR}

	openssl genrsa -out ${KEYFILE} 4096
	envsubst < ${CLIENTCONF} | openssl req -config - -new -key ${KEYFILE} -out ${CSRFILE}
	openssl x509 -req -in ${CSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${CERTFILE} -days 365 -sha256

	export CACERT=`cat $CACERTFILE`
	export CLIENTKEY=`cat $KEYFILE`
	export CLIENTCERT=`cat $CERTFILE`
	export VPNTAKEY=`cat $VPNTAKEYFILE`
	envsubst < $TCPCLIENTCONF > ${DIR}/${NAME}.ovpn
}

createCA

createServer

createClient

createServerConfig