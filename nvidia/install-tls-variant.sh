#!/bin/sh
# Install the official "tls/" variant of libnvidia-tls (64 and 32 bit).
#
# The default 340.108 build calls arch_prctl(ARCH_SET_FS, ...) and breaks
# glibc's TLS (tcache corruption / abort).  The tls/ build from the same
# installer uses normal glibc TLS.
#
# Usage:
#   NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 sudo ./install-tls-variant.sh

set -eu

SRC=${NVIDIA_SRC:-/root/NVIDIA-Linux-x86_64-340.108}
STORE=${TLSSTORE:-/usr/local/share/nvidia-340-tls}

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }

has_syscall() {
    # A good variant has no syscall instruction.
    objdump -d "$1" 2>/dev/null | grep -q '[[:space:]]syscall' && return 0
    return 1
}

install_one() {
    bits="$1"; libdir="$2"; cand="$3"; backup="$4"
    [ -e "$libdir/libnvidia-tls.so.340.108" ] || {
        echo "skip ${bits}-bit: $libdir/libnvidia-tls.so.340.108 not installed"
        return 0
    }
    [ -e "$cand" ] || {
        echo "missing ${bits}-bit tls variant: $cand" >&2
        return 1
    }
    if has_syscall "$cand"; then
        echo "REFUSING ${bits}-bit candidate (still contains syscall): $cand" >&2
        return 1
    fi

    mkdir -p "$STORE/$bits"
    cp -f "$cand" "$STORE/$bits/libnvidia-tls.so.340.108"

    if [ ! -e "$backup" ]; then
        cp -a "$libdir/libnvidia-tls.so.340.108" "$backup"
        echo "backed up $libdir/libnvidia-tls.so.340.108 -> $backup"
    fi
    cp -f "$cand" "$libdir/libnvidia-tls.so.340.108"
    echo "installed ${bits}-bit tls variant -> $libdir/libnvidia-tls.so.340.108"
}

install_one 64 /usr/lib64 "$SRC/tls/libnvidia-tls.so.340.108" \
    /root/libnvidia-tls.so.340.108.orig-fshack
install_one 32 /usr/lib32 "$SRC/32/tls/libnvidia-tls.so.340.108" \
    /root/libnvidia-tls.so.340.108.i386.orig-fshack

# No ldconfig here: the fixup script does ldconfig first and then re-creates
# the glvnd symlinks (ldconfig would otherwise undo them).
echo "done; run /usr/local/sbin/nvidia-340-fixups.sh (or reboot)"
