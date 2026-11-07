# 32-bit NVIDIA 340.108 patches (Steam / games)

The 32-bit userspace has exactly the same two problems as the 64-bit one:

1. **`libnvidia-tls.so.340.108` (32-bit)** — the default build calls
   `arch_prctl(ARCH_SET_FS, …)` and corrupts glibc's TLS. The installer's
   `32/tls/libnvidia-tls.so.340.108` is the good build:

   | file | size | syscalls |
   |---|---|---|
   | `32/libnvidia-tls.so.340.108` | 13820 | 2 (bad) |
   | `32/tls/libnvidia-tls.so.340.108` | 13752 | 0 (good) |

2. **libglvnd shims** — 340 has no libglvnd vendor. The 32-bit entry points
   must point at NVIDIA's 32-bit monolithic libGL:

   ```
   /usr/lib32/libGL.so.1     -> libGL.so.340.108
   /usr/lib32/libGLX.so.0    -> libGL.so.340.108
   /usr/lib32/libOpenGL.so.0 -> libGL.so.340.108
   ```

Apply both:

```sh
sudo NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 nvidia/patch-32bit.sh
```

The script verifies the TLS build has zero `syscall` instructions and all
three symlinks are correct. The main `nvidia-340-fixups.sh` (boot service +
Portage hook) also maintains the 32-bit links, so the 32-bit state survives
package updates.

## The 32-bit X11 runtime is separate

The NVIDIA installer provides only the driver libraries. 32-bit GL
applications also need the 32-bit X11 stack. On this test machine it was not
installed, so a 32-bit GL client could not start yet:

```
/usr/lib32/libX11.so.6: missing
```

Install the `abi_x86_32` versions (Portage will pull the rest of the 32-bit
X11 chain), for example:

```sh
mkdir -p /etc/portage/package.use
cat >> /etc/portage/package.use/steam32 <<'EOF'
x11-libs/libX11 abi_x86_32
x11-libs/libXext abi_x86_32
EOF
emerge --oneshot x11-libs/libX11 x11-libs/libXext
```

Steam will pull many more 32-bit dependencies. On the tested system the
`steam-launcher` dependency `sys-libs/libudev-compat` was keyword-masked
(`~amd64`); add it to `package.accept_keywords` if you install Steam.

Build and run the 32-bit test once the runtime is present:

```sh
gcc -m32 -O2 -o /tmp/glxtest32 tools/glxtest32.c -lGL -lX11
DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority /tmp/glxtest32
# RENDERER=GeForce 8600M GT/PCIe/SSE2
```

Use `tools/verify-32bit.sh` to check the driver-side state at any time.
