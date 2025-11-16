#!/bin/bash
#
# setup-laptop.sh
# Copyright (C) 2022 Kovid Goyal <kovid at kovidgoyal.net>
#
# Distributed under terms of the MIT license.
# Available at: https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/setup-laptop.sh

# To connect to wireless in liveusb
# echo -e "[General]\nEnableNetworkConfiguration=true" > /etc/iwd/main.conf
# iwctl --passphrase PASSPHRASE station wlan0 connect KovidTheGreat

set -o nounset
set -o errexit

# Setup the disk (change DISK if needed on new machine)
DISK="/dev/nvme0n1"
SCRIPT_PATH="${BASH_SOURCE[0]}"

function main() {
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
DNS=
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
    genfstab -U /mnt >> /mnt/etc/fstab
    cp "$SCRIPT_PATH" /mnt/root/bootstrap.sh
    arch-chroot /mnt /root/bootstrap.sh in_chroot
    rm /bootstrap/root/bootstrap.sh
    umount /mnt/boot
    umount /mnt
}

function in_chroot() {
    hostnamectl hostname getafix
    timedatectl set-timezone Asia/Kolkata
    timedatectl set-ntp true
    timedatectl set-local-rtc 0
    echo "en_IN UTF-8" >> /etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    localectl set-locale en_IN
    systemctl enable systemd-resolved
    systemctl disable systemd-networkd
    systemctl enable iwd

    # Setup pacman
    sed -i 's/#Color/Color/g' /etc/pacman.conf
    cat << EOF >> /etc/pacman.conf
[multilib]
Include = /etc/pacman.d/mirrorlist
EOF

    pacman -Syu

    needed_software=(
        python-pynvim telegram-desktop zeal python-pyinotify mutt alsa-plugins
        mlocate gnome-themes-standard lynx wl-clipboard python-netifaces python-pexpect gvim
        offlineimap ipython python-feedparser libxkbcommon-x11 unison ttf-ubuntu-font-family
        ttf-fira-code firefox python-urwid breeze breeze-icons qt6ct python-yaml translate-toolkit
        usb_modeswitch hplip cups cups-pdf python-matplotlib bzr dos2unix irssi python-sphinx vim-spell-en
        gimp python-nose python-chardet mkvtoolnix-cli dnsmasq libmtp sshfs mosh samba ctags
        python-docs sigil python-pyenchant python-pyxattr unrar zsh-completions zsh-autosuggestions
        zsh-syntax-highlighting python-psutil python-flake8 python-pyflakes python-pycodestyle
        xautomation python-pytz tig htop xorg-server chromium xorg-xmodmap pavucontrol wvdial autossh
        xorg-xauth openssh pipewire pipewire-pulse pipewire-alsa lib32-pipewire winetricks
        xorg-xinit xorg-xsetroot xorg-xrdb ttf-liberation ttf-dejavu icoutils ntfs-3g python-polib
        efibootmgr cmake python-paramiko rsnapshot dnsutils mpv alsa-utils alsa-tools
        xorg-xdpyinfo python-pygit2 screen net-tools vde2 python-markdown greetd
        libreoffice-fresh libreoffice-fresh-en-gb p7zip python-lxml python-lxml-html-clean xorg-xev
        wev python-dateutil python-dnspython python-css-parser python-cssselect podofo libwmf
        imagemagick poppler-qt6 chmlib python-pillow shared-mime-info libunrar icu python-apsw
        python-pycountry libvncserver freerdp lib32-alsa-plugins cloc texlive texlive-lang msmtp-mta
        openjpeg2 spice-gtk remmina xdotool pv wine-mono wine_gecko mpg123 lib32-mpg123 jshon
        python-virtualenv optipng python-requests smtp-forwarder base-devel rsync modemmanager
        inkscape xorg-xkill jnettop xorg-server-xwayland pax-utils python-pygments nodejs npm
        speedtest-cli httpie gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly python-jedi
        linux-headers python-xxhash simde vimpager libva-mesa-driver mesa-vdpau mesa-libgl python-gobject
        gdb socat noto-fonts noto-fonts-emoji noto-fonts-cjk gsimplecal pyqt-builder python-pyqt6-webengine
        qt6-tools qt6-imageformats qt6ct poppler-qt6 python-yaml python-apsw python-isort python-twine
        python-wheel python-msgpack python-unrardll python-pysocks clang llvm npm xorg-xinput
        python-html5-parser mailutils python-humanize jq jxrlib fd python-wheel python-pyqtwebengine
        xcursor-themes libwebp-utils python-pydbus sip python-beautifulsoup4 python-html5-parser python-regex ripgrep
        python-certifi terminus-font python-mechanize python-dbus urlscan python-prompt_toolkit slurp grim
        xclip zip iw python-zeroconf python-html2text python-pychm bluez bluez-utils python-build mypy
        python-docutils-stubs python-sphinx-inline-tabs python-sphinxext-opengraph python-sphinx-furo
        python-sphinx-autobuild python-pip dash fish pciutils startup-notification yajl xcb-util-xrm
        autossh man man-pages fzf python-sphinx-copybutton librsync wayland wayland-protocols links
        python-pycryptodome ttf-nerd-fonts-symbols python-scipy python-py7zr speech-dispatcher
        python-cchardet inetutils wireless-regdb fprintd cdrtools usbutils kernel-modules-hook
        qemu qemu-user-static qemu-user-static-binfmt edk2-armvirt edk2-ovmf qemu-system-aarch64 swtpm
        upx gopls staticcheck python-black wireguard-tools aria2 wofi ruff lld yt-dlp python-lsp-server
        python-rope lua-language-server wlr-randr python-jaconv python-pykakasi vulkan-swrast vulkan-icd-loader
        hyprland xdg-desktop-portal-hyprland hypridle hyprpicker swaync brightnessctl onnxruntime espeak-ng kitty

        # these alongwith sac-gui below are needed for managing autheticode signing via hardware token
        libp11 pcsclite pkcs11-helper opensc python-pykcs11
    )

    # Install needed software
    pacman -S --needed "${args[@]}"

    # test environments
    pacman -S --needed gnome-shell sway swayidle xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-wlr gnome-session gnome-terminal

    # KDE Applications
    pacman -S --needed dolphin ark okteta okular kde-cli-tools ffmpegthumbs plasma-workspace kdegraphics-thumbnailers konsole plasma-wayland-protocols plasma-desktop wayland-utils

    # Install yay
    mkdir yay && chown nobody:nobody yay && cd yay && pacman -S --needed git base-devel
    sudo -u nobody sh -c 'export HOME=`pwd`; git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -s'
    pacman -U yay/*pkg.tar.*
    cd .. && rm -rf yay

    # Install deps from AUR
    useradd -m -G sys,users,video,lp,audio,wheel,input,disk,storage -s /bin/zsh kovid
    echo "Set password for root"
    passwd
    echo "Set password for kovid"
    passwd kovid

    # Allow passwordless sudo for all users in wheel group
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL"  >> /etc/sudoers
    sudo -u kovid yay -S python-lsp-isort python-pylsp-mypy python-lsp-ruff python-launchpadlib transifex-cli ttf-symbola mu sac-gui

    set +e
    video=$(lspci | grep VGA | grep -o AMD)
    set -o errexit

    gpu_info=$(lspci | grep -i 'vga\|3d\|display')
    if echo "$gpu_info" | grep -iq "AMD\|ATI"; then
        pacman -S xf86-video-amdgpu vulkan-radeon
    elif echo "$gpu_info" | grep -iq "NVIDIA"; then
        pacman -S nvidia-open nvidia-utils
    else
        pacman -S libva-intel-driver vulkan-intel
    fi
    systemctl enable bluetooth
    systemctl enable sshd
    # service for using authenticode signing via hardware token
    systemctl enable pcscd.service
    echo FONT=ter-132b >> /etc/vconsole.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-sysctl.conf
    echo loop >> /etc/modules-load.d/loopback.conf
    echo SystemMaxUse=100M >> /etc/systemd/journald.conf
    echo "KillUserProcesses=yes" >> /etc/systemd/logind.conf
    # Dont suspend on lid close with power connected
    echo "HandleLidSwitchExternalPower=ignore" >> /etc/systemd/logind.conf
    # Only wait at most 5s for services to stop
    echo "DefaultTimeoutStopSec=5s" >> /etc/systemd/system.conf
    # Dont overcharge the battery on ThinkPads
    systemctl enable tpacpi-bat
    # Cleanup old kernel modules
    systemctl enable linux-modules-cleanup.service
    chsh -s /bin/zsh

    # Setup kovid account
    mkdir /home/kovid/.ssh /backup /t
    curl -fSsL https://raw.githubusercontent.com/kovidgoyal/kovidgoyal.github.io/refs/heads/master/authorized_keys > /home/kovid/.ssh/authorized_keys
    chown -R kovid:kovid /home/kovid /t

    # Setup greetd for login with session.py
    cat << EOF > /etc/greetd/config.toml
[terminal]
vt = 1
[default_session]
command = "/home/kovid/work/env/session.py"
user = "kovid"
EOF
    # Setup automatic unlock for the execrable GNOME keyring used by Chromium
    cat << EOF > /etc/pam.d/greetd
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
EOF

    # Install bootloader
    bootctl install
    cat <<EOF > "/boot/loader/loader.conf"
default  arch.conf
timeout  0
console-mode max
editor   no
EOF
    root_partition_uuid=$(cat /etc/fstab | grep UUID | head -n1 | cut -f1 | cut -d= -f2)
    cat <<EOF > "/boot/loader/entries/arch.conf"
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$root_partition_uuid rw
EOF

    bootctl
    echo
    echo "Check the bootctl output above to verify it has found the entry and then reboot"
}

case "$ACTION" in
    in_chroot)
        shift
        in_chroot "$@"
        ;;
    *)
        main
        ;;
esac
