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
    && apt-get install -y openvpn iptables dumb-init \
#
#
#
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "iptables-restore < /etc/iptables/rules.v4 && exec openvpn --config /etc/openvpn/server.conf"]
