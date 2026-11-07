#!/bin/sh
# Install the NVIDIA 340.108 userspace wiring on an OpenRC Gentoo system.
#
# Prerequisites:
#   - the 340.108 .run extracted to $NVIDIA_SRC
#     (default /root/NVIDIA-Linux-x86_64-340.108)
#   - Xorg 1.20.x installed with GLX enabled
#   - this script run as root

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=${NVIDIA_SRC:-/root/NVIDIA-Linux-x86_64-340.108}
EXTRA=/usr/lib64/xorg/modules/extensions

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -d "$SRC" ] || { echo "missing NVIDIA source tree: $SRC" >&2; exit 1; }

# The base userspace must already be installed (nvidia/install-userspace.sh).
if [ ! -e /usr/lib64/xorg/modules/drivers/nvidia_drv.so ] || \
   [ ! -e /usr/lib64/libnvidia-glcore.so.340.108 ]; then
    echo "NVIDIA userspace is not installed." >&2
    echo "Run nvidia/install-userspace.sh first (see nvidia/README-install-driver.md)." >&2
    exit 1
fi

echo "== NVIDIA userspace files =="
# The .run installs the 32-bit libGL but often not the 64-bit one.
if [ ! -e /usr/lib64/libGL.so.340.108 ] && [ -e "$SRC/libGL.so.340.108" ]; then
    install -m755 "$SRC/libGL.so.340.108" /usr/lib64/
    echo "  installed /usr/lib64/libGL.so.340.108"
fi
if [ ! -e /usr/lib32/libGL.so.340.108 ] && [ -e "$SRC/32/libGL.so.340.108" ]; then
    install -m755 "$SRC/32/libGL.so.340.108" /usr/lib32/
    echo "  installed /usr/lib32/libGL.so.340.108"
fi
if [ ! -e "$EXTRA/libglx.so.340.108" ] && [ -e "$SRC/libglx.so.340.108" ]; then
    install -m755 "$SRC/libglx.so.340.108" "$EXTRA/"
    echo "  installed $EXTRA/libglx.so.340.108"
fi

echo "== libnvidia-tls =="
NVIDIA_SRC="$SRC" "$DIR/nvidia/install-tls-variant.sh"

echo "== fixup script =="
install -m755 "$DIR/system/nvidia-340-fixups.sh" /usr/local/sbin/nvidia-340-fixups.sh

echo "== OpenRC service =="
if command -v rc-update >/dev/null 2>&1; then
    install -m755 "$DIR/system/nvidia-340-fixups.init" /etc/init.d/nvidia-340-fixups
    rc-update add nvidia-340-fixups default >/dev/null 2>&1 || true
    rc-service nvidia-340-fixups restart >/dev/null 2>&1 || \
        rc-service nvidia-340-fixups start >/dev/null 2>&1 || true
    echo "  enabled nvidia-340-fixups (default runlevel)"
else
    echo "  WARNING: rc-update not found; install a boot hook manually" >&2
fi

echo "== Portage postinst hook =="
HOOK="$DIR/system/portage-bashrc"
if [ -e /etc/portage/bashrc ] && grep -q 'nvidia-340-fixups.sh' /etc/portage/bashrc; then
    echo "  /etc/portage/bashrc already contains the hook"
elif [ -e /etc/portage/bashrc ]; then
    cp -a /etc/portage/bashrc /root/bashrc.pre-nvidia-340
    printf '\n' >> /etc/portage/bashrc
    cat "$HOOK" >> /etc/portage/bashrc
    echo "  appended hook to /etc/portage/bashrc (backup: /root/bashrc.pre-nvidia-340)"
else
    install -m644 "$HOOK" /etc/portage/bashrc
    echo "  installed /etc/portage/bashrc"
fi

echo "== Xorg mask =="
mkdir -p /etc/portage/package.mask
install -m644 "$DIR/system/package.mask/xorg-server-121" \
    /etc/portage/package.mask/xorg-server-121
echo "  installed /etc/portage/package.mask/xorg-server-121"

echo "== apply =="
/usr/local/sbin/nvidia-340-fixups.sh

echo
echo "Done. Verify with:"
echo "  $DIR/tools/verify.sh"
echo "  DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority glxinfo -B"
