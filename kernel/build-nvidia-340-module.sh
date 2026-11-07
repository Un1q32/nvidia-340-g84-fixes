#!/bin/sh
# Build and install the unmodified NVIDIA 340.108 kernel module.
#
# The .run's own nvidia-installer can fail on GCC 16; these KCFLAGS relax
# errors that the 2019 source triggers.  No source changes are made.
#
# Usage:
#   NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 sudo ./build-nvidia-340-module.sh

set -eu

SRC=${NVIDIA_SRC:-/root/NVIDIA-Linux-x86_64-340.108}
KERNEL=${KERNEL:-$(uname -r)}
K="$SRC/kernel"

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -d "$K" ] || { echo "missing $K (extract the .run first)" >&2; exit 1; }

cd "$K"
make module \
    SYSSRC=/usr/src/linux \
    SYSOUT=/usr/src/linux \
    NV_BUILD_MODULE_INSTANCES= \
    KCFLAGS="-std=gnu11 \
        -Wno-error=implicit-function-declaration \
        -Wno-error=implicit-int \
        -Wno-error=incompatible-pointer-types \
        -Wno-error=int-conversion \
        -Wno-error=return-mismatch"

install -m644 nvidia.ko "/lib/modules/$KERNEL/kernel/drivers/video/nvidia.ko"
depmod -a "$KERNEL"

echo "installed nvidia.ko for $KERNEL"
echo "reboot (or unload/reload nvidia) to use it"
