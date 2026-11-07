#!/bin/sh
# Apply/verify the NVIDIA 340.108 fixes for 32-bit binaries (Steam/games).
#
# The 32-bit userspace has the same two problems as 64-bit:
#   1. the FS-hack libnvidia-tls breaks glibc,
#   2. 340 has no libglvnd vendor, so libGLX/libOpenGL need a shim.
#
# This script installs the official tls/ variant and re-asserts the 32-bit
# symlinks. It does NOT install the 32-bit X11 runtime; package dependencies
# are separate (see README-32bit.md).
#
# Usage:
#   NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 sudo ./patch-32bit.sh

set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=${NVIDIA_SRC:-/root/NVIDIA-Linux-x86_64-340.108}
LIB=/usr/lib32

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -e "$LIB/libGL.so.340.108" ] || {
    echo "32-bit NVIDIA userspace missing ($LIB/libGL.so.340.108)." >&2
    echo "Install it with nvidia/install-userspace.sh first." >&2
    exit 1
}

echo "== 32-bit libnvidia-tls =="
NVIDIA_SRC="$SRC" "$DIR/install-tls-variant.sh"

echo "== 32-bit glvnd shims =="
if [ -x /usr/local/sbin/nvidia-340-fixups.sh ]; then
    /usr/local/sbin/nvidia-340-fixups.sh
else
    ln -sfn libGL.so.340.108 "$LIB/libGL.so.1"
    ln -sfn libGL.so.340.108 "$LIB/libGLX.so.0"
    ln -sfn libGL.so.340.108 "$LIB/libOpenGL.so.0"
fi

echo "== checks =="
n=$(objdump -d "$LIB/libnvidia-tls.so.340.108" 2>/dev/null |
    grep -c '[[:space:]]syscall' || true)
[ "$n" = 0 ] || { echo "FAIL: 32-bit libnvidia-tls still has $n syscalls" >&2; exit 1; }
for l in libGL.so.1 libGLX.so.0 libOpenGL.so.0; do
    [ "$(readlink "$LIB/$l")" = libGL.so.340.108 ] || {
        echo "FAIL: $LIB/$l not pointing at libGL.so.340.108" >&2
        exit 1
    }
done
echo "32-bit driver patch applied."

if [ ! -e "$LIB/libX11.so.6" ]; then
    echo
    echo "WARNING: the 32-bit X11 runtime is not installed."
    echo "32-bit GL applications (Steam/games) will not start until it is."
    echo "See nvidia/README-32bit.md for the abi_x86_32 package steps."
fi
