#!/bin/sh

CAKEYFILE="${CADIR}/ca.key"
CACERTFILE="${CADIR}/ca.crt"

export SERIALDIR="${VPNDIR}/serials"
mkdir -p ${SERIALDIR}

createKey()
{
	local KEYFILE=$1

	mkdir -p `dirname ${KEYFILE}`

	if [ "${KEYALG}" = "RSA" ];
	then
		echo "Generating RSA ${KEYFILE}"
		openssl genrsa -out ${KEYFILE} ${KEYBITS:-4096}
	else
		echo "Generating ECDSA(prime256v1) ${KEYFILE}"
		openssl ecparam -name prime256v1 -genkey -noout -out ${KEYFILE}
	fi
}

createDH()
{
	if [ -f ${VPNDHFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${VPNDHFILE}`
	openssl dhparam -out ${VPNDHFILE} ${VPNDHBITS:-2048}
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

	createKey ${CAKEYFILE}

	mkdir -p `dirname ${CACERTFILE}`
	CACONF="${TEMPLATESDIR}/openssl/ca.conf.template"
	envsubst < ${CACONF} | grep -Ev "^[^=]+=[ ]+$" | openssl req -config - -x509 -new -nodes -extensions v3_ca -key ${CAKEYFILE} -sha256 -days ${CACERTDAYS:-3650} -out ${CACERTFILE}
}

createServer()
{
	if [ -f ${VPNCERTFILE} ];
	then
		return
	fi

	mkdir -p `dirname ${VPNCAFILE}`
	cp ${CACERTFILE} ${VPNCAFILE}

	createKey ${VPNKEYFILE}

	VPNCONF="${TEMPLATESDIR}/openssl/vpn.conf.template"
	VPNCSRFILE="${VPNDIR}/vpn.csr"
	mkdir -p `dirname ${VPNCSRFILE}`
	envsubst < ${VPNCONF} | grep -Ev "^[^=]+=[ ]+$" | openssl req -config - -new -key ${VPNKEYFILE} -out ${VPNCSRFILE}
	openssl x509 -req -in ${VPNCSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${VPNCERTFILE} -days ${VPNCERTDAYS:-365} -sha256

	createTA
	createDH
}

createServerConfig()
{
	SERVERCONF="${TEMPLATESDIR}/openvpn/server.conf.template"

	if [ -z "${VPN_SPLIT}" ];
	then
		export VPN_DEF1="push \"redirect-gateway def1 bypass-dhcp\"";
		if [ -z "${VPN_DNS1}" ]; then VPN_DNS1="1.1.1.1"; fi
		if [ -z "${VPN_DNS2}" ]; then VPN_DNS2="8.8.8.8"; fi
	fi

	if [ ! -z "${VPN_ROUTE1}" ]; then export VPN_ROUTE1="push \"route ${VPN_ROUTE1}\""; fi
	if [ ! -z "${VPN_ROUTE2}" ]; then export VPN_ROUTE2="push \"route ${VPN_ROUTE2}\""; fi
	if [ ! -z "${VPN_ROUTE3}" ]; then export VPN_ROUTE3="push \"route ${VPN_ROUTE3}\""; fi

	if [ -z "${VPN_IPV6_SERVER_BLOCK}" ]; then export VPN_IPV6_SERVER_BLOCK=""; fi
	if [ -z "${VPN_IPV6_PUSHES}" ]; then export VPN_IPV6_PUSHES="push \"block-ipv6\""; fi

	VPN_PROTO=tcp envsubst < ${SERVERCONF} > ${TCPCONF}
	VPN_PROTO=udp envsubst < ${SERVERCONF} > ${UDPCONF}
}

createClient()
{
	CLIENTCONF=${TEMPLATESDIR}/openssl/client.conf.template

	NAME=${CLIENT_CN}

	local DIR="${CLIENTSDIR}/${NAME}"
	local KEYFILE="${DIR}/${NAME}.key"
	local CSRFILE="${DIR}/${NAME}.csr"
	local CERTFILE="${DIR}/${NAME}.crt"

	if [ ! -f ${CERTFILE} ];
	then
		createKey ${KEYFILE}

		envsubst < ${CLIENTCONF} | grep -Ev "^[^=]+=[ ]+$" | openssl req -config - -new -key ${KEYFILE} -out ${CSRFILE}
		openssl x509 -req -in ${CSRFILE} -CA ${CACERTFILE} -CAkey ${CAKEYFILE} -CAcreateserial -out ${CERTFILE} -days ${CLIENTCERTDAYS:-365} -sha256
	fi

	# store serial number
	SERIAL=`openssl x509 -noout -serial -in ${CERTFILE} | sed "s/serial=//" | tr '[:upper:]' '[:lower:]'`
	SERIALFILE="${SERIALDIR}/${SERIAL}"
	if [ ! -f ${SERIALFILE} ];
	then
		echo "${NAME}" > "${SERIALFILE}"
	fi

	export CACERT=`cat $CACERTFILE`
	export CLIENTKEY=`cat $KEYFILE`
	export CLIENTCERT=`cat $CERTFILE`
	export VPNTAKEY=`cat $VPNTAKEYFILE`

	if [ -z "${VPN_ADDR}" ]; then export VPN_ADDR=${VPN_CN}; fi

	if [ -z "${VPN_IPV6_ROUTE1}" ]; then export VPN_IPV6_ROUTE1="route-ipv6 ::/1"; fi
	if [ -z "${VPN_IPV6_ROUTE2}" ]; then export VPN_IPV6_ROUTE2="route-ipv6 8000::/1"; fi

	if [ ! -z "${VPN_DNS1}" ]; then export VPN_DNS1="push \"dhcp-option DNS ${VPN_DNS1}\""; fi
	if [ ! -z "${VPN_DNS2}" ]; then export VPN_DNS2="push \"dhcp-option DNS ${VPN_DNS2}\""; fi

	export CONNECTION1=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto udp\n</connection>\n"`
	export CONNECTION2=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto tcp-client\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto tcp-client\n</connection>\n"`
	export CONNECTION2=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto udp\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-tcp-udp.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto tcp-client\n</connection>\n"`
	export CONNECTION2=""
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-tcp-only.ovpn

	export CONNECTION1=`echo "<connection>\nremote ${VPN_ADDR} ${VPN_PORT}\nproto udp\n</connection>\n"`
	envsubst < ${TEMPLATESDIR}/openvpn/client.ovpn.template > ${DIR}/${NAME}-udp-only.ovpn
}

createCA

createServer

createClient

createServerConfig
