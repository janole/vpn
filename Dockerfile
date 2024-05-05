FROM debian:bookworm-slim

LABEL maintainer="Jan Ole Suhr <ole@janole.com>"

RUN true \
    #
    #
    #
    && apt-get update && apt-get -y upgrade \
    #
    #
    #
    && apt-get install -y openvpn iptables dumb-init gettext \
    #
    # Clean-up ...
    #
    && rm -rf /var/lib/apt/lists/*

ENV CONFDIR=/conf
ENV VPNDIR=${CONFDIR}/openvpn
ENV CLIENTSDIR=${CONFDIR}/clients
ENV TEMPLATESDIR=/.templates

ENV VPNCAFILE=${VPNDIR}/ca.crt
ENV VPNKEYFILE=${VPNDIR}/vpn.key
ENV VPNCERTFILE=${VPNDIR}/vpn.crt
ENV VPNDHFILE=${VPNDIR}/dh.pem
ENV VPNTAKEYFILE=${VPNDIR}/ta.key

ENV UDPCONF=${VPNDIR}/udp-server.conf
ENV TCPCONF=${VPNDIR}/tcp-server.conf

COPY ./rules.v4 /etc/iptables/rules.v4
COPY ./templates ${TEMPLATESDIR}/
COPY ./init-certs.sh /init-certs.sh
COPY ./start-ovpn.sh /start-ovpn.sh

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/start-ovpn.sh"]
