#!/bin/bash
#
# setup-laptop.sh
# Copyright (C) 2022 Kovid Goyal <kovid at kovidgoyal.net>
#
# Distributed under terms of the MIT license.
#

set -o nounset
set -o errexit

# Note that currently systemd-networkd has broken matching on SSID, therefore
# I have added a rule to the router's DHCP server to assign 192.168.1.5 by MAC address
cat << EOF > /mnt/etc/systemd/network/20-wired.network
[Match]
Name=en*

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=10

[IPv6AcceptRA]
RouteMetric=10
EOF

cat << EOF > /mnt/etc/systemd/network/21-wireless-home.network
[Match]
Name=wl*
SSID=KovidTheGreat

[Network]
Address=192.168.1.55/24
Gateway=192.168.1.1
DNS=8.8.8.8
DNS=1.1.1.1
IgnoreCarrierLoss=3s
EOF

cat << EOF > /mnt/etc/systemd/network/30-wireless-dhcp.network
[Match]
Name=wl*

[Network]
DHCP=yes
DNS=8.8.8.8
DNS=1.1.1.1
IgnoreCarrierLoss=3s

[DHCPv4]
RouteMetric=20

[IPv6AcceptRA]
RouteMetric=20
EOF

cat << EOF > "/mnt/etc/wpa_supplicant/wpa_supplicant-$(ip a | grep -o ': wl.\+\?:' | cut -d' ' -f2 | cut -d: -f1).conf"
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
ap_scan=1
country=IN
fast_reauth=1

EOF

ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
wpa_passphrase KovidTheGreat >> "/mnt/etc/wpa_supplicant/$(ip a | grep -o ': wl.\+\?:' | cut -d' ' -f2 | cut -d: -f1).conf"
genfstab -U /mnt >> /mnt/etc/fstab
curl 'https://github.com/kovidgoyal/kovidgoyal.github.io/raw/master/setup-laptop2.sh' > /mnt/root/setup-laptop.sh
arch-chroot /mnt
