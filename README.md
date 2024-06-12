![Docker Image Build Status](https://github.com/janole/vpn/workflows/Docker%20Image/badge.svg)  ![Security Scan Status](https://github.com/janole/vpn/workflows/Security%20Scan/badge.svg)

An easy-to-use OpenVPN server running in a Docker container. 

### Requirements

- Linux host with Docker
- OpenVPN compatible client on your laptop, desktop computer or mobile phone

### Set-up

Create a `compose.yaml` file with the following content:

````yaml
name: vpn

services:
  tcp: &vpn
    image: ${IMAGE:-janole/vpn}
    restart: unless-stopped
    volumes:
      - ./conf/openvpn:/conf/openvpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun
    ports:
      - ${VPN_PORT:-1194}:${VPN_PORT:-1194}/tcp
    depends_on:
      config:
        condition: service_completed_successfully

  udp:
    <<: *vpn
    ports:
      - ${VPN_PORT:-1194}:${VPN_PORT:-1194}/udp
    environment:
      - SERVERCONF=/conf/openvpn/udp-server.conf

  config:
    image: ${IMAGE:-janole/vpn}
    env_file:
      - .env
    volumes:
      - ./conf:/conf
    command: "/init-vpn.sh"
````

Create a `.env` configuration file with the following content:

````env
CA_CN="ca.my-own-site.org"
VPN_CN="vpn.my-own-site.org"
CLIENT_CN="my-vpn-client"
````

- `CA_CN` can be a random name
- `VPN_CN` should be the domain name ("FQDN") of your VPN
- `CLIENT_CN` is just a name for your client profile

Now you can start the VPN with the following command:

````bash
$ docker compose up -d
[+] Running 4/4
 ✔ Network vpn_default     Created                                         0.1s 
 ✔ Container vpn-config-1  Exited                                          1.3s 
 ✔ Container vpn-tcp-1     Started                                         2.7s 
 ✔ Container vpn-udp-1     Started                                         2.6s 
````

Congratulations! The VPN should be up and running after a while ...

(Please note that on **first start**, the `config` container will create all the necessary private keys and certificates. Generating the Diffie-Hellman parameters might take some minutes depending on the machine you're running the VPN on.)

After successful start of the VPN, you can show the generated configuration files with:

````bash
$ find conf -type f
conf/ca/ca.crt
conf/ca/ca.key
conf/ca/ca.srl
conf/clients/my-vpn-client/my-vpn-client.csr
conf/clients/my-vpn-client/my-vpn-client.key
conf/clients/my-vpn-client/my-vpn-client.crt
conf/clients/my-vpn-client/my-vpn-client-udp-only.ovpn
conf/clients/my-vpn-client/my-vpn-client.ovpn
conf/clients/my-vpn-client/my-vpn-client-tcp-udp.ovpn
conf/clients/my-vpn-client/my-vpn-client-tcp-only.ovpn
conf/openvpn/ca.crt
conf/openvpn/vpn.crt
conf/openvpn/tcp-server.conf
conf/openvpn/dh.pem
conf/openvpn/ta.key
conf/openvpn/vpn.csr
conf/openvpn/udp-server.conf
conf/openvpn/vpn.key
````

Now you can download any of the `*.ovpn` configuration files and import them to your `OpenVPN` client.

Download the default OVPN file (`my-vpn-client.ovpn`):

````bash
$ scp vpn.my-own-site.org:vpn/conf/clients/my-vpn-client/my-vpn-client.ovpn .
my-vpn-client.ovpn                                                       100% 2302     7.5KB/s   00:00
````

Import the OVPN file to OpenVPN: <br>
<img width="512" alt="Bildschirmfoto 2024-06-09 um 23 28 09" src="https://github.com/janole/vpn/assets/1439712/07d851ae-44d8-4452-b08a-76f92eb61877">

### TO-DO

- [ ] Add the possibility to revoke client certificates (CRL)
- [ ] Add a web interface ("access server")
