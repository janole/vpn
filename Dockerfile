FROM debian:bookworm-slim

LABEL maintainer="Jan Ole Suhr <ole@janole.com>"

ENV DEBIAN_FRONTEND noninteractive

RUN true \
#
# Update package list
#
    && apt-get update \
#
# Upgrade packages to fix potential security issues:
# - This will inflate our image, but the base image isn't updated quickly enough
#    
    && apt-get upgrade -y \
#
# Install all necessary packages
#
    && apt-get install -y openvpn iptables gettext dumb-init \
#
# Clean-up ...
#
    && rm -rf /var/lib/apt/lists/*

ENV CADIR=/conf/ca
ENV VPNDIR=/conf/openvpn
ENV CLIENTSDIR=/conf/clients
ENV TEMPLATESDIR=/.templates

ENV VPNCAFILE=${VPNDIR}/ca.crt
ENV VPNKEYFILE=${VPNDIR}/vpn.key
ENV VPNCERTFILE=${VPNDIR}/vpn.crt
ENV VPNDHFILE=${VPNDIR}/dh.pem
ENV VPNTAKEYFILE=${VPNDIR}/ta.key

ENV UDPCONF=${VPNDIR}/udp-server.conf
ENV TCPCONF=${VPNDIR}/tcp-server.conf

ENV VPN_PORT=1194

ENV CA_COUNTRY=US
ENV VPN_COUNTRY=US
ENV CLIENT_COUNTRY=US

COPY ./templates ${TEMPLATESDIR}/
COPY ./scripts/* /

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/start-vpn.sh"]
