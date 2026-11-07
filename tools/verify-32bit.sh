#!/bin/sh
# Verify the 32-bit NVIDIA 340.108 driver-side state.
# The 32-bit X11 runtime is reported as a warning, not a driver failure.

fails=0
warns=0
ok()   { printf '  OK   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fails=$((fails + 1)); }
warn() { printf '  WARN %s\n' "$*"; warns=$((warns + 1)); }

LIB=/usr/lib32

echo "== 32-bit NVIDIA libraries =="
for f in "$LIB/libGL.so.340.108" "$LIB/libnvidia-glcore.so.340.108" \
         "$LIB/libnvidia-tls.so.340.108"; do
    if [ -e "$f" ] && file "$f" | grep -q 'ELF 32-bit'; then
        ok "$f (ELF 32-bit)"
    else
        bad "$f missing or not ELF 32-bit"
    fi
done

echo "== libnvidia-tls (0 syscalls = good) =="
if [ -e "$LIB/libnvidia-tls.so.340.108" ]; then
    n=$(objdump -d "$LIB/libnvidia-tls.so.340.108" 2>/dev/null |
        grep -c '[[:space:]]syscall' || true)
    [ "$n" = 0 ] && ok "0 syscalls" || bad "$n syscalls (FS-hack variant)"
fi

echo "== glvnd shims =="
for l in libGL.so.1 libGLX.so.0 libOpenGL.so.0; do
    if [ "$(readlink "$LIB/$l" 2>/dev/null)" = libGL.so.340.108 ]; then
        ok "$LIB/$l -> libGL.so.340.108"
    else
        bad "$LIB/$l -> $(readlink "$LIB/$l" 2>/dev/null || echo missing)"
    fi
done

echo "== 32-bit X11 runtime =="
if [ -e "$LIB/libX11.so.6" ]; then
    ok "libX11.so.6 present"
    if [ -e "$LIB/libXext.so.6" ]; then
        ok "libXext.so.6 present"
    else
        warn "libXext.so.6 missing"
    fi
else
    warn "32-bit X11 runtime missing (needed by Steam/games, not by the driver)"
fi

echo
[ "$fails" = 0 ] && echo "32-bit driver-side checks passed ($warns warning(s))"
[ "$fails" = 0 ] || echo "$fails check(s) failed"
exit "$([ "$fails" = 0 ] && echo 0 || echo 1)"
