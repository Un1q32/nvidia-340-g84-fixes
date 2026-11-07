#!/bin/sh
# Re-assert the userspace wiring required by NVIDIA 340.108 on this system.
#
# Why this exists:
#  - Xorg/mesa upgrades overwrite the libglx.so symlink (server GLX module).
#  - Mesa/libglvnd upgrades overwrite libGL.so.1 and libGLX.so.0.  340.108
#    has no libglvnd vendor library (libGLX_nvidia.so.0), so the glvnd
#    dispatcher is pointed at NVIDIA's monolithic libGL instead.
#  - A driver reinstall may put back the "FS hack" libnvidia-tls, which
#    breaks glibc 2.43 (ARCH_SET_FS -> tcache corruption).
#
# IMPORTANT ORDERING: ldconfig rewrites libGLX.so.0 based on the SONAME of
# the installed glvnd library.  Therefore ldconfig must run FIRST and all
# symlinks must be (re)created AFTER it.
#
# Safe to run repeatedly.  Does nothing if the NVIDIA files are absent.

EXTRA=/usr/lib64/xorg/modules/extensions
SRC=/root/NVIDIA-Linux-x86_64-340.108
TLSSTORE=/usr/local/share/nvidia-340-tls

# Update the loader cache first; ldconfig rewrites libGLX.so.0.
if [ "${NVIDIA_FIXUP_SKIP_LDCONFIG:-0}" != "1" ]; then
    ldconfig 2>/dev/null
fi

# 1) Server-side GLX: NVIDIA's module, not the stock Xorg one.
if [ -e "$EXTRA/libglx.so.340.108" ]; then
    ln -sfn libglx.so.340.108 "$EXTRA/libglx.so"
fi

# 2) Client-side OpenGL: NVIDIA's legacy libGL (no libglvnd vendor in 340).
#    64-bit and 32-bit (Steam, games).
if [ -e /usr/lib64/libGL.so.340.108 ]; then
    ln -sfn libGL.so.340.108 /usr/lib64/libGL.so.1
    # glvnd shims: libGLX.so.0 and libOpenGL.so.0 are normally the libglvnd
    # dispatchers; with 340 there is no NVIDIA vendor, so point them at the
    # monolithic libGL.
    ln -sfn libGL.so.340.108 /usr/lib64/libGLX.so.0
    ln -sfn libGL.so.340.108 /usr/lib64/libOpenGL.so.0
fi
if [ -e /usr/lib32/libGL.so.340.108 ]; then
    ln -sfn libGL.so.340.108 /usr/lib32/libGL.so.1
    ln -sfn libGL.so.340.108 /usr/lib32/libGLX.so.0
    ln -sfn libGL.so.340.108 /usr/lib32/libOpenGL.so.0
fi

# 3) libnvidia-tls: use the variant that does NOT switch fs_base.
fix_tls() {
    inst="$1"; tlsdir="$2"; srcdir="$3"
    [ -e "$inst" ] || return 0
    if [ -e "$tlsdir/libnvidia-tls.so.340.108" ]; then
        s="$tlsdir/libnvidia-tls.so.340.108"
    elif [ -e "$srcdir/libnvidia-tls.so.340.108" ]; then
        s="$srcdir/libnvidia-tls.so.340.108"
    else
        return 0
    fi
    cmp -s "$inst" "$s" || cp -f "$s" "$inst"
}
fix_tls /usr/lib64/libnvidia-tls.so.340.108 "$TLSSTORE/64" "$SRC/tls"
fix_tls /usr/lib32/libnvidia-tls.so.340.108 "$TLSSTORE/32" "$SRC/32/tls"

exit 0
