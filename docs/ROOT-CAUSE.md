# Root cause investigation

Test machine:

* MacBook Pro 4,1, GeForce 8600M GT (G84M), 2.9 GB RAM
* Gentoo, kernel 5.4.302, `intel_iommu=off`
* glibc 2.43, libglvnd 1.7.0, Xorg 1.20.14
* NVIDIA 340.108 (last branch for G84)

Two separate failures were found.

---

## Failure 1: `malloc(): unaligned tcache chunk detected`

Xorg died during `(II) Initializing extension GLX`:

```
malloc_printerr("malloc(): unaligned tcache chunk detected")
tcache_get_n
tcache_get
__libc_calloc          (calloc(0x50, 1))
AddExtension           <- called from libglx.so
InitExtensions
```

`calloc(0x50)` requests a 96-byte chunk, i.e. tcache bin 4
(`csize2tidx(0x60) = 4`).

### What was ruled out

* **Kernel copy_to_user into the heap.** The NVIDIA kernel module was
  instrumented to log every `os_memcpy_to_user` whose destination was inside
  the process brk heap, including `irq=`, `pid=`, and the would-be glibc chunk
  header. All writes were synchronous (`irq=0`, same PID), none covered the
  tcache slot, and none overran a chunk.
* **GPU DMA.** `os_lock_user_pages` was instrumented; no heap page was pinned.
* **Userspace writes to the tcache slot.** A hardware watchpoint on
  `tcache->entries[4]` saw only legitimate tcache traffic.
* **Post-mortem tcache state.** Xorg's SIGABRT handler itself allocates/frees,
  so the tcache in a core dump is already mutated. Stopping at the SIGABRT
  (or at the printerr cold path) was necessary.

### The actual mechanism

A breakpoint at `__libc_calloc+480` (the "unaligned tcache" printerr path)
showed:

```
bad_entry = 0xa8
tcache    = 0x... (heap)
tc_idx    = 4
nb        = 0x60
slot      = tcache + 0xb8   (= &entries[4])
```

So `entries[4]` literally contained `0xa8`. A valid tcache entry is always a
16-byte aligned chunk pointer, so this could not have been written by
`tcache_put`.

At the same point, `%fs_base` was a heap address, not glibc's TLS block, and
the tcache pointer at `%fs:<offset>` was different from the one observed at
the first `AddExtension`. There was only one thread (confirmed with
`info threads`).

`gdb` syscall catching showed the culprit:

```
_nv006tls () from /usr/lib64/libnvidia-tls.so.340.108
  arch_prctl(ARCH_GET_FS, ...)
  arch_prctl(ARCH_SET_FS, 0x55d00e8f0680)   <- heap address
```

`libnvidia-tls.so.340.108` (the default variant) switches the thread's FS base
to a driver-private TLS block. glibc 2.43 then reads `tcache` from that block;
`entries[4]` happens to be `0xa8`, and `tcache_get_n` aborts. Older glibc
versions tolerated this; 2.43's tcache integrity checks do not.

### Fix

The same NVIDIA installer ships a second build:

```
tls/libnvidia-tls.so.340.108       13008 bytes, 0 syscalls, normal glibc TLS
libnvidia-tls.so.340.108           12696 bytes, 2 syscalls, ARCH_SET_FS hack
```

Installing the `tls/` variant (64- and 32-bit) fixes the crash. This is a
binary replacement with an official NVIDIA build; see
`nvidia/checksums.txt`.

After this fix Xorg ran, GLX initialized, and the 2D desktop worked. But
`glxinfo` still reported no visuals.

---

## Failure 2: no GLX fbconfigs

The server was fine. A small client linked against the **legacy** libGL
reported:

```
server_vendor = NVIDIA Corporation
server_version = 1.4
getfbconfigs  = 284
choosefbconfig = 132
```

The stock `glxinfo`/`glxgears` failed with
`couldn't find RGB GLX visual or fbconfig` because they are linked against
**libglvnd**, not libGL:

```
/usr/bin/glxgears:
  NEEDED libGLX.so.0
  NEEDED libGLdispatch.so.0
```

`libGLX.so.0` is libglvnd's dispatcher. It loads a per-vendor backend named
`libGLX_<vendor>.so.0` and calls its `__glx_Main`. Only Mesa's backend existed:

```
/usr/lib64/libGLX_mesa.so.0   -> exports __glx_Main
```

NVIDIA 340.108 predates libglvnd vendor support and ships no
`libGLX_nvidia.so.0`. Its monolithic `libGL.so.340.108` also does not export
`__glx_Main`, so it cannot be used directly as a libglvnd vendor.

Mesa's backend cannot drive the NVIDIA server (it looks for a Mesa/DRI
driver), so any libGLX-linked client sees zero fbconfigs.

### Fix

Use NVIDIA's monolithic libGL for the glvnd entry points:

```
/usr/lib64/libGL.so.1     -> libGL.so.340.108
/usr/lib64/libGLX.so.0    -> libGL.so.340.108
/usr/lib64/libOpenGL.so.0 -> libGL.so.340.108
```

and the 32-bit equivalents. `libOpenGL.so.0` was needed because the standard
mesa-progs build links it for GL entry points; without it, `glxgears` runs but
prints `GL_RENDERER=(null)`.

### Why the ordering matters

`ldconfig` inspects `libGLX.so.0.0.0` (SONAME `libGLX.so.0`) and rewrites the
`libGLX.so.0` symlink to point at it. The same is true for
`libOpenGL.so.0.0.0`. Therefore:

1. run `ldconfig` first,
2. create the symlinks after it.

This is why `system/nvidia-340-fixups.sh` has `ldconfig` at the top. Running
`ldconfig` after the symlinks silently undoes the shim.

### Update safety

The fixup runs at boot and after relevant package merges. The Portage hook in
`/etc/portage/bashrc` applies to:

```
media-libs/libglvnd   (owns libGL.so.1, libGLX.so.0, libOpenGL.so.0)
media-libs/mesa
x11-base/xorg-server  (owns the extensions/libglx.so symlink)
x11-drivers/nvidia-drivers
x11-apps/mesa-progs
media-libs/freeglut
```

It uses the sandbox `addwrite` helper so the symlinks can be changed from the
`pkg_postinst` phase. Rebuilding `media-libs/libglvnd` was used as the test:
the package overwrites all three symlinks, the hook restores them, and
`glxgears` keeps working without a reboot.

---

## Evidence commands

```sh
# libnvidia-tls variant identification
stat -c '%s %n' libnvidia-tls.so.340.108 tls/libnvidia-tls.so.340.108
objdump -d libnvidia-tls.so.340.108 | grep -c syscall    # 2 = bad
objdump -d tls/libnvidia-tls.so.340.108 | grep -c syscall # 0 = good

# glvnd state
ldconfig -p | grep -E 'libGLX.so.0|libOpenGL.so.0|libGL.so.1'
ls -l /usr/lib64/libGL.so.1 /usr/lib64/libGLX.so.0 /usr/lib64/libOpenGL.so.0

# server-side 3D
DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority glxinfo -B
```
