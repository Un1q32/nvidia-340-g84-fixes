#!/bin/sh
# Verify the NVIDIA 340.108 userspace wiring.
# Does not change anything.

fails=0
ok()   { printf '  OK   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; fails=$((fails + 1)); }

check_link() {
    want="$1"; path="$2"
    if [ -L "$path" ] && [ "$(readlink "$path")" = "$want" ]; then
        ok "$path -> $want"
    else
        bad "$path -> $(readlink "$path" 2>/dev/null || echo '(missing)'), want $want"
    fi
}

echo "== library links =="
check_link libglx.so.340.108 /usr/lib64/xorg/modules/extensions/libglx.so
check_link libGL.so.340.108   /usr/lib64/libGL.so.1
check_link libGL.so.340.108   /usr/lib64/libGLX.so.0
check_link libGL.so.340.108   /usr/lib64/libOpenGL.so.0
if [ -e /usr/lib32/libGL.so.340.108 ]; then
    check_link libGL.so.340.108 /usr/lib32/libGL.so.1
    check_link libGL.so.340.108 /usr/lib32/libGLX.so.0
    check_link libGL.so.340.108 /usr/lib32/libOpenGL.so.0
fi

echo "== libnvidia-tls (0 syscalls = good) =="
for f in /usr/lib64/libnvidia-tls.so.340.108 /usr/lib32/libnvidia-tls.so.340.108; do
    [ -e "$f" ] || continue
    n=$(objdump -d "$f" 2>/dev/null | grep -c '[[:space:]]syscall' || true)
    [ "$n" = 0 ] && ok "$f (0 syscalls)" || bad "$f ($n syscalls; FS-hack variant)"
done

echo "== kernel module =="
if lsmod 2>/dev/null | grep -q '^nvidia '; then
    ok "nvidia module loaded"
else
    bad "nvidia module not loaded"
fi

echo "== live GLX =="
if command -v glxinfo >/dev/null 2>&1; then
    disp=${DISPLAY:-:0}
    auth=${XAUTHORITY:-/home/uniq/.Xauthority}
    out=$(DISPLAY="$disp" XAUTHORITY="$auth" timeout 20 glxinfo -B 2>&1 || true)
    echo "$out" | grep -q 'direct rendering: Yes' \
        && ok "direct rendering" || bad "direct rendering"
    echo "$out" | grep -q 'GeForce 8600M GT' \
        && ok "GeForce 8600M GT renderer" || bad "renderer not NVIDIA GeForce 8600M GT"
else
    echo "  skip  glxinfo not installed"
fi

echo
[ "$fails" = 0 ] && { echo "all checks passed"; exit 0; }
echo "$fails check(s) failed"; exit 1
