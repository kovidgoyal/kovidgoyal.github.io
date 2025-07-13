#!/bin/bash
#
# setup-laptop.sh
# Copyright (C) 2022 Kovid Goyal <kovid at kovidgoyal.net>
#
# Distributed under terms of the MIT license.
#

# To connect to wireless in liveusb (the last line is a workaround for buggy ath12k wireless driver)
# echo "[General]\nEnableNetworkConfiguration=true\nControlPortOverNL80211=false" > /etc/iwd/main.conf
# iwctl --passphrase PASSPHRASE station wlan0 connect KovidTheGreat

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

interface=$(ip a | grep -o ': wl.\+\?:' | cut -d' ' -f2 | cut -d: -f1)
network_config="/mnt/etc/wpa_supplicant/wpa_supplicant-$interface.conf"

cat << EOF > "$network_config"
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
ap_scan=1
country=IN
fast_reauth=1

EOF

ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
echo "Enter passphrase for KovidTheGreat"
wpa_passphrase KovidTheGreat >> "$network_config"
echo "Enter passphrase for Kphone"
wpa_passphrase Kphone >> "$network_config"
wpa_passphrase 'Westwood Villa' Westwoodvill@ >> "$network_config"
genfstab -U /mnt >> /mnt/etc/fstab
curl 'https://github.com/kovidgoyal/kovidgoyal.github.io/raw/master/setup-laptop2.sh' > /mnt/root/setup-laptop.sh
arch-chroot /mnt
