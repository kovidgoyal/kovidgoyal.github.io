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

function main() {
    if [[ -z "$ACTION" ]]; then
        echo "Must provide hostname"
        exit 1
    fi
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
    cat << EOF > /etc/systemd/network/20-ovh.network
[Match]
Name=en*

[Network]
DHCP=true
EOF
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf

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
