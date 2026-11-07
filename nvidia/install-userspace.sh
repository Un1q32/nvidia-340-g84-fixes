#!/bin/sh
# Install the NVIDIA 340.108 userspace (no kernel module).
#
# The kernel module is built separately by
# ../kernel/build-nvidia-340-module.sh because the 340.108 installer's own
# build fails with GCC 16.
#
# WARNING: stop the display manager / X before running this.  The installer
# replaces libGL/libglx/nvidia_drv; the fixups in ../install.sh repair the
# glvnd/TLS wiring afterwards.

set -eu

SRC=${NVIDIA_SRC:-/root/NVIDIA-Linux-x86_64-340.108}
INST="$SRC/nvidia-installer"

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
[ -x "$INST" ] || { echo "missing installer: $INST (run fetch-driver.sh)" >&2; exit 1; }

echo "Stopping display-manager (if present)..."
rc-service display-manager stop >/dev/null 2>&1 || true

echo "Installing NVIDIA 340.108 userspace (no kernel module)..."
"$INST" \
    --no-kernel-module \
    --no-x-check \
    --no-nouveau-check \
    --no-questions \
    --accept-license

echo
echo "Userspace installed.  Now:"
echo "  1. ../kernel/build-nvidia-340-module.sh"
echo "  2. ../install.sh   (TLS variant, glvnd shims, boot/Portage hooks)"
