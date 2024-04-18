#!/bin/bash

apt-get update
apt-get install -y strongswan
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/^#\(net\.ipv4\.ip_forward=1\)/\1/' /etc/sysctl.conf

# Configure StrongSwan
cat << EOF > /etc/ipsec.conf
config setup
    uniqueids=never

conn %default
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!
    dpdaction=clear
    dpddelay=300s
    rekey=no

conn vpn
    left=%defaultroute
    leftid=${vm1_public_ip}
    leftsubnet=${subnet_cidr_vpc1_sub1}
    right=${vm2_public_ip}
    rightsubnet=${subnet_cidr_vpc2_sub1}
    auto=start
    ike=aes256-sha1-modp1024!
    esp=aes256-sha1!
    authby=secret     # Use shared key authentication
    keyexchange=ikev2
    ikelifetime=60m
    lifetime=1h
    rekeymargin=3m
    keylife=20m
EOF

# Save the PSK to the StrongSwan secrets file
echo "${vm1_public_ip} ${vm2_public_ip} : PSK \"${PSK}\"" > /etc/ipsec.secrets

# Restart StrongSwan to apply the changes
service strongswan restart
