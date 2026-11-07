# libnvidia-tls: why the default build breaks glibc 2.43

NVIDIA 340.108 installs two different `libnvidia-tls` implementations:

| path (inside the .run) | size | syscalls | TLS behaviour |
|---|---|---|---|
| `libnvidia-tls.so.340.108` | 12696 | 2 | `ARCH_GET_FS` + `ARCH_SET_FS` |
| `tls/libnvidia-tls.so.340.108` | 13008 | 0 | normal glibc TLS |

The default build contains a private TLS "workaround". During GLX init it runs:

```
arch_prctl(ARCH_GET_FS, &old)
arch_prctl(ARCH_SET_FS, <driver heap block>)
```

It then continues with the thread's FS base pointing at the driver's private
block. glibc reads its own TLS variables (including `tcache`) from that block.
glibc 2.43 detects an invalid tcache entry and aborts:

```
malloc(): unaligned tcache chunk detected
```

The `tls/` build is the same driver API but uses normal, per-thread glibc TLS.
Installing it is the fix. This is an official NVIDIA binary from the same
installer, not a hand-written patch.

## Identify the variants

```sh
objdump -d /usr/lib64/libnvidia-tls.so.340.108 | grep -c syscall
# 2 = default (bad)
# 0 = tls/ variant (good)

stat -c '%s %n' /usr/lib64/libnvidia-tls.so.340.108
# 12696 = default (bad)
# 13008 = tls/ variant (good)
```

For the 32-bit build the sizes are 13820 (bad) and 13752 (good).

## Install

```sh
sudo ./install-tls-variant.sh
```

The script:

1. locates `$NVIDIA_SRC/tls/libnvidia-tls.so.340.108` (64-bit) and
   `$NVIDIA_SRC/32/tls/libnvidia-tls.so.340.108` (32-bit),
2. refuses a candidate that still contains a `syscall` instruction,
3. backs up the current file once to
   `/root/libnvidia-tls.so.340.108.orig-fshack`
   (and `.i386.orig-fshack` for 32-bit),
4. copies the good variant into `/usr/local/share/nvidia-340-tls/{64,32}`
   (used by the boot/hook fixup) and into `/usr/lib64` or `/usr/lib32`.

The fixup service checks both copies on every boot, so a driver reinstall
cannot leave the bad variant behind silently.

## Checksums seen on the test machine

See `checksums.txt`. Do not rely on them across different driver builds; use
the `syscall` test, which is version-independent.
