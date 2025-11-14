#!/bin/bash
# Reboot into rescue mode and ssh in and run this script
# Edit the TZ and AUTHORIZED_KEYS variables first, if needed.
# curl -fSsL https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/setup-ovh-arch.sh > /tmp/bootstrap.sh && chmod +x /tmp/bootstrap.sh && /tmp/bootstrap.sh myhostname

TZ="Asia/Kolkata"
DISK="/dev/sdb"
AUTHORIZED_KEYS="https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/authorized_keys"

set -o nounset
set -o errexit


ACTION="$1"
SCRIPT_PATH="${BASH_SOURCE[0]}"
ipv4_address=""
ipv4_prefix=""
ipv4_gateway=""
ipv6_address=""
ipv6_prefix="128"
ipv6_gateway=""


get_network_info() {
    # Get the default route interface. This is typically the primary interface.
    local iface=$(ip -4 route | grep default | sed -e "s/^.*dev \([^ ]*\) .*$/\1/")
    if [ -z "$iface" ]; then
        echo "Could not determine default IPv4 interface." >&2
        exit 1
    fi

    # Get the IP address and prefix for that interface
    local ip_info=$(ip -4 addr show dev "$iface" | grep "inet " | awk '{print $2}')
    if [ -z "$ip_info" ]; then
        echo "Could not determine IPv4 address for interface $iface." >&2
        exit 1
    fi
    ipv4_address=$(echo "$ip_info" | cut -d'/' -f1)
    ipv4_prefix=$(echo "$ip_info" | cut -d'/' -f2)

    # Get the gateway from the default route
    ipv4_gateway=$(ip -4 route | grep default | awk '{print $3}')
    if [ -z "$ipv4_gateway" ]; then
        echo "Could not determine default IPv4 gateway." >&2
        exit 1
    fi
    echo "IPv4 Address: $ipv4_address"
    echo "IPv4 Prefix: $ipv4_prefix"
    echo "IPv4 Gateway: $ipv4_gateway"

    # OVHCloud does not support DNS for IPv6 and thus their
    # rescue environment (currently Debian 12) has only the IPv6 address but not gateway
    ipv6_address=$(ip -6 route | head -n1 | cut -f1 -d" ")
    # read the gateway from the cloud-init file
    local ipv6_gateway_info=$(grep gw /etc/network/interfaces.d/50-cloud-init | head -n1 | tr -s ' ' | cut -d' ' -f7)
    if [ -z "$ipv6_gateway_info" ]; then
        echo "Could not determine IPv6 gateway"
        exit 1
    fi

    ipv6_gateway=$(echo "$ipv6_gateway_info" | cut -d'/' -f1)
    ipv6_prefix=$(echo "$ipv6_gateway_info" | cut -d'/' -f2)
    # alternately, assume the gateway is the address with last component replaced by 1
    # ipv6_gateway=$(echo -n "$ipv6_address" | sed 's/\(.*\):[^:]*$/\1:1/' | sed 's/\(.*\)::$/\1::1/')
    echo "IPv6 Address: $ipv6_address"
    echo "IPv6 Prefix: $ipv6_prefix"
    echo "IPv6 Gateway: $ipv6_gateway"
}

function main() {
    if [[ -z "$ACTION" ]]; then
        echo "Must provide hostname"
        exit 1
    fi
    get_network_info
    cd /tmp
    curl -fSsL https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst > /tmp/archlinux.tar.zst

    sgdisk --zap-all "$DISK"
    sgdisk -n 1:2048:+1M -c 1:"BIOS Boot Partition" -t 1:EF02 "$DISK"
    sgdisk -n 2:0:0 --typecode=2:8300 --change-name=2:"Linux Root" "$DISK"
    mkfs.ext4 -F "${DISK}2"
    sgdisk -p "$DISK"

    mkdir -p /bootstrap
    mount -t tmpfs tmpfs /bootstrap
    mount "${DISK}2" /bootstrap
    cd /bootstrap
    tar xf /tmp/archlinux.tar.zst --numeric-owner --strip-components=1
    mount "${DISK}2" /bootstrap/mnt

    sed -i -e 's@#Server = https://mirror.rackspace.com@Server = https://mirror.rackspace.com@' /bootstrap/etc/pacman.d/mirrorlist
    sed -i -e 's/#ParallelDownloads/ParallelDownloads/' /bootstrap/etc/pacman.conf
    cp "$SCRIPT_PATH" /bootstrap/root/bootstrap.sh
    cd /
    /bootstrap/bin/arch-chroot /bootstrap /root/bootstrap.sh 'do_pacstrap'
    /bootstrap/bin/arch-chroot /bootstrap/mnt/ /root/bootstrap.sh 'finalize' "$ACTION"

    # Network configuration
    cat << EOF > /bootstrap/etc/systemd/network/20-ovh.network
[Match]
Name=en*

[Network]
Address=${ipv4_address}/${ipv4_prefix}
Gateway=${ipv4_gateway}
Address=${ipv6_address}/${ipv6_prefix}
Gateway=${ipv6_gateway}
DNS=1.1.1.1
DNS=8.8.8.8
DNS=2606:4700:4700::1111
DNS=2001:4860:4860::8888
EOF


    rm /bootstrap/root/bootstrap.sh
    umount /bootstrap/mnt
    umount /bootstrap
    umount /bootstrap
    echo
    echo "All done now reboot the VPS from the OVH control panel"
}


function do_pacstrap() {
    pacman-key --init
    pacman-key --populate archlinux
    pacstrap /mnt base linux-lts linux-firmware openssh grub
    genfstab -U /mnt >> /mnt/etc/fstab
}

function finalize() {
    sed -i -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
    sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
    grub-install --target=i386-pc "$DISK"
    grub-mkconfig -o /boot/grub/grub.cfg
    pacman --noconfirm -S vim kitty-terminfo

    # Network
    systemctl enable systemd-networkd
    systemctl enable sshd

    pacman -Syu --noconfirm

    # Locale
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf
    locale-gen

    # Pacman mirrors
    pacman --noconfirm -S rsync reflector
    reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist

    # Hostname and timezone
    echo "$1" > /etc/hostname
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    systemctl enable systemd-timesyncd.service

    # initramfs
    touch /etc/vconsole.conf
    mkinitcpio -P

    mkdir -p /root/.ssh
    curl -fSsL "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
}

case "$ACTION" in
    do_pacstrap)
        shift
        do_pacstrap "$@"
        ;;
    finalize)
        shift
        finalize "$@"
        ;;
    *)
        main
        ;;
esac
