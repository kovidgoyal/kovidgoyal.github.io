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

# Setup networking
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

mkdir -p /mnt/var/lib/iwd /mnt/etc/iwd && chmod og-rwx /mnt/var/lib/iwd
cat <<EOF > /mnt/etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true
EOF
# needed for buggy ath12k driver in current laptop (Qualcomm wifi 7)
echo "ControlPortOverNL80211=false" >> /mnt/etc/iwd/main.conf
echo -n "Enter passphrase for KovidTheGreat:"
read -s password
echo "[Security]\nPassphrase=$password" > "/mnt/var/lib/iwd/KovidTheGreat.psk"
chmod og-rw  "/mnt/var/lib/iwd/KovidTheGreat.psk"
cat <<EOF >> "/mnt/var/lib/iwd/KovidTheGreat.psk"
[IPv4]
Address=192.168.1.55
Netmask=255.255.255.0
Gateway=192.168.1.1
Broadcast=192.168.1.255
DNS=1.1.1.1
EOF

echo "[Security]\nPassphrase=$password" > "/mnt/var/lib/iwd/Kphone.psk"
chmod og-rw  "/mnt/var/lib/iwd/Kphone.psk"

echo "[Security]\nPassphrase=Westwoodvill@" > "/mnt/var/lib/iwd/Westwood Villa.psk"
chmod og-rw  "/mnt/var/lib/iwd/Westwood Villa.psk"


# chroot into new system
genfstab -U /mnt >> /mnt/etc/fstab
curl 'https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/setup-laptop2.sh' > /mnt/root/setup-laptop.sh
arch-chroot /mnt
