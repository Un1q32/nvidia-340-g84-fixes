#!/bin/sh
# Download and extract NVIDIA 340.108 (the last driver for the G84M).
# The .run is proprietary and is NOT part of this repository.
#
# Usage:
#   NVIDIA_WORK=/root sudo ./fetch-driver.sh
#   # -> /root/NVIDIA-Linux-x86_64-340.108
#
# Then install userspace with install-userspace.sh, build the kernel module
# with ../kernel/build-nvidia-340-module.sh, and run ../install.sh.

set -eu

VERSION=340.108
RUN="NVIDIA-Linux-x86_64-$VERSION.run"
URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/$VERSION/$RUN"
SHA256=c671d4f1b7c09bc1af079b98b447adb06d704b04f802f7045a611fa50133b71b
WORK=${NVIDIA_WORK:-/root}
DEST="$WORK/NVIDIA-Linux-x86_64-$VERSION"

mkdir -p "$WORK"
cd "$WORK"

if [ -d "$DEST/kernel" ]; then
    echo "already extracted: $DEST"
    exit 0
fi

if [ ! -f "$RUN" ]; then
    echo "downloading $URL"
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "$RUN" "$URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$RUN" "$URL"
    else
        echo "need curl or wget" >&2; exit 1
    fi
fi

echo "verifying $RUN"
printf '%s  %s\n' "$SHA256" "$RUN" | sha256sum -c -

chmod +x "$RUN"
echo "extracting"
sh "$RUN" --extract-only

[ -d "$DEST" ] || { echo "extraction did not create $DEST" >&2; exit 1; }
echo
echo "extracted to: $DEST"
echo "next: NVIDIA_SRC=$DEST ./install-userspace.sh"
