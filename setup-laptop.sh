#!/bin/bash
#
# setup-laptop.sh
# Copyright (C) 2022 Kovid Goyal <kovid at kovidgoyal.net>
#
# Distributed under terms of the MIT license.
# Available at: https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/setup-laptop.sh

# To connect to wireless in liveusb (the last line is a workaround for buggy ath12k wireless driver)
# echo -e "[General]\nEnableNetworkConfiguration=true\nControlPortOverNL80211=false" > /etc/iwd/main.conf
# iwctl --passphrase PASSPHRASE station wlan0 connect KovidTheGreat

set -o nounset
set -o errexit

# Setup the disk (change DISK if needed on new machine)
DISK="/dev/nvme0n1"
sgdisk --zap-all "$DISK"
# Create EFI System Partition: type ef00
sgdisk --new=1:0:+550M --typecode=1:ef00 --change-name=1:"EFI System" "$DISK"
# Create Swap Partition: type 8200
sgdisk --new=2:0:+32G --typecode=2:8200 --change-name=2:"Linux Swap" "$DISK"
# Create Root Partition: rest of disk, type 8300
sgdisk --new=3:0:0 --typecode=3:8300 --change-name=3:"Linux Root" "$DISK"
# Print the new partition table
sgdisk -p "$DISK"
mkfs.fat -F 32 "${DISK}p1"
mkswap "${DISK}p2"
mkfs.ext4 "${DISK}p3"
mount "${DISK}p3" /mnt
mount --mkdir "${DISK}p1" /mnt/boot
swapon "${DISK}p2"

# Install essential software
pacstrap -K /mnt base linux linux-firmware iwd impala amd-ucode exfatprogs e2fsprogs nvim

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
cat <<EOF > "/mnt/var/lib/iwd/KovidTheGreat.psk"
[Security]
Passphrase=$password
[IPv4]
Address=192.168.1.5
Netmask=255.255.255.0
Gateway=192.168.1.1
Broadcast=192.168.1.255
DNS=1.1.1.1
EOF
chmod og-rw  "/mnt/var/lib/iwd/KovidTheGreat.psk"

cat <<EOF > "/mnt/var/lib/iwd/Kphone.psk"
[Security]
Passphrase=$password
EOF
chmod og-rw  "/mnt/var/lib/iwd/Kphone.psk"

cat <<EOF > "/mnt/var/lib/iwd/Westwood Villa.psk"
[Security]
Passphrase=Westwoodvill@
EOF
chmod og-rw  "/mnt/var/lib/iwd/Westwood Villa.psk"


# chroot into new system
curl 'https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/setup-laptop2.sh' > /mnt/root/setup-laptop.sh
genfstab -U /mnt >> /mnt/etc/fstab
echo "chrooting into newly installed system, run /root/setup-laptop.sh for next stage"
arch-chroot /mnt
