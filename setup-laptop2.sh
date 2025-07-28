#!/bin/bash
#
# setup-laptop.sh
# Copyright (C) 2022 Kovid Goyal <kovid at kovidgoyal.net>
#
# Distributed under terms of the MIT license.
#

set -o nounset
set -o errexit

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

# Install needed software
pacman -S --needed python-pynvim telegram-desktop zeal python-pyinotify mutt alsa-plugins \
    mlocate gnome-themes-standard lynx wl-clipboard python-netifaces python-pexpect gvim \
    offlineimap ipython python-feedparser libxkbcommon-x11 unison ttf-ubuntu-font-family \
    ttf-fira-code firefox python-urwid breeze breeze-icons qt5ct python-yaml translate-toolkit \
    usb_modeswitch hplip cups cups-pdf python-matplotlib bzr dos2unix irssi python-sphinx vim-spell-en \
    gimp python-nose python-chardet mkvtoolnix-cli dnsmasq libmtp sshfs mosh samba ctags \
    python-docs sigil python-pyenchant python-pyxattr unrar zsh-completions zsh-autosuggestions \
    zsh-syntax-highlighting python-psutil python-flake8 python-pyflakes python-pycodestyle \
    xautomation python-pytz tig htop xorg-server chromium xorg-xmodmap pavucontrol wvdial autossh \
    xorg-xauth openssh pipewire pipewire-pulse pipewire-alsa lib32-pipewire winetricks \
    xorg-xinit xorg-xsetroot xorg-xrdb ttf-liberation ttf-dejavu icoutils ntfs-3g python-polib \
    efibootmgr cmake python-paramiko rsnapshot dnsutils mpv alsa-utils alsa-tools qt5-tools \
    qt5-imageformats qt5-doc xorg-xdpyinfo python-pygit2 screen net-tools vde2 python-markdown \
    libreoffice-fresh libreoffice-fresh-en-gb p7zip python-lxml python-lxml-html-clean xorg-xev \
    wev python-dateutil python-dnspython python-css-parser python-cssselect podofo libwmf \
    imagemagick poppler-qt5 chmlib python-pillow shared-mime-info libunrar icu python-apsw \
    python-pycountry libvncserver freerdp lib32-alsa-plugins cloc texlive texlive-lang msmtp-mta \
    openjpeg2 spice-gtk remmina xdotool pv wine-mono wine_gecko mpg123 lib32-mpg123 jshon \
    python-virtualenv optipng python-requests smtp-forwarder base-devel rsync modemmanager \
    inkscape xorg-xkill jnettop xorg-server-xwayland pax-utils python-pygments nodejs npm \
    speedtest-cli httpie gst-libav gst-plugins-base gst-plugins-good gst-plugins-ugly python-jedi \
    linux-headers python-xxhash simde vimpager libva-mesa-driver mesa-vdpau mesa-libgl python-gobject \
    gdb socat noto-fonts noto-fonts-emoji noto-fonts-cjk gsimplecal pyqt-builder python-pyqt6-webengine \
    qt6-tools qt6-imageformats qt6ct poppler-qt6 python-yaml python-apsw python-isort python-twine \
    python-wheel python-msgpack python-unrardll python-pysocks clang llvm npm xorg-xinput \
    python-html5-parser mailutils python-humanize jq jxrlib fd python-wheel python-pyqtwebengine \
    xcursor-themes python-pydbus sip python-beautifulsoup4 python-html5-parser python-regex ripgrep \
    python-certifi terminus-font python-mechanize python-dbus urlscan python-prompt_toolkit slurp grim \
    xclip zip iw python-zeroconf python-html2text python-pychm bluez bluez-utils python-build mypy \
    python-docutils-stubs python-sphinx-inline-tabs python-sphinxext-opengraph python-sphinx-furo \
    python-sphinx-autobuild python-pip dash fish pciutils startup-notification yajl xcb-util-xrm \
    autossh man man-pages fzf python-sphinx-copybutton librsync wayland wayland-protocols links \
    python-pycryptodome ttf-nerd-fonts-symbols python-scipy python-py7zr speech-dispatcher \
    python-cchardet inetutils wireless-regdb fprintd cdrtools usbutils kernel-modules-hook \
    qemu qemu-user-static qemu-user-static-binfmt edk2-armvirt edk2-ovmf qemu-system-aarch64 swtpm \
    upx gopls staticcheck python-black wireguard-tools aria2 wofi ruff lld yt-dlp python-lsp-server \
    python-rope lua-language-server wlr-randr python-jaconv python-pykakasi vulkan-swrast vulkan-icd-loader \
    hyprland xdg-desktop-portal-hyprland hypridle hyprpicker swaync brightnessctl kitty

# test environments
pacman -S --needed gnome-shell sway swayidle xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-wlr gnome-session gnome-terminal

# KDE Applications
pacman -S --needed dolphin ark okteta okular kde-cli-tools ffmpegthumbs plasma-workspace kdegraphics-thumbnailers konsole plasma-wayland-protocols

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
sudo -u kovid yay -S python-lsp-isort python-pylsp-mypy python-lsp-ruff python-launchpadlib transifex-client ttf-symbola piper-tts-bin mu

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
cat << EOF > /home/kovid/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD751ZMQy0/zf169hUZOphZ9fwjz6j4sl5l04zfErCK+sIV5y4V+B+20BWJU5kySRztUtTBSD6Av4V8dYmGOesE9KjMZ0d0P95q3vWlkhpxQV2z2npTO6PLx6kIxJxQwkGSUsLLXW+N4Do+/pPHlagcO94yNyAi4uJ1TRpF7vRMaas3frUdeYFp2KSD/61m0ue7WeFeEtUKuZejs3smBRDfNuQBo/NVLxZQLT7Z02039Hmh0Z27F8NVcbt8iBG9i/HLa5e/wH82gxn2ASPVqgeRlJa5UmCTw1p2E2qUCWH0PeIXQCXEszexKPaC3UuA9qWrkGIkigE1H7MDXxYS4uCSLFvO+swo4mt4Tw3UD1BdobD6EoeVnSPGApmwRIYGkLFjtL6RlGla6kpSH3OX8z2BQaUkOC/Jfihb83i+ltg4w9PXZ5hbe/iznOGUUhF5rQVSjz2E03Dy4s4gwJ2vIPdpqgAp6domFe1hJ7v3pbhwPeZBcyyxfAa+wQlST0rCj+YCYB7yANBJbm1HN4YnTw2L3rM55TrUdIudyE1GlQKh8fZxpB17HyKb6A3hZpeXLMSfrkA7fsRMrJ9lD+C2bnotFaIdrktNISl47wMR4lO32Ks5B29CVZaxOtw1nm+Q1yoInrg4qODpff5IV4pp8LO3e7WZzUqYthafFVtzn50zrw== kovid@kovidgoyal.net
EOF
chown -R kovid:kovid /home/kovid /t

# Setup fingerprint login
# sudo fprintd-enroll kovid
# fprintd-verify kovid
# add the following line before any others in /etc/pam.d/system-local-login
# auth      sufficient pam_fprintd.so


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
echo "Check the bootctl output above to verify it has found the entry and then reboot"
