# Final system wiring

This is the state produced by `install.sh` on the tested machine
(Gentoo, Xorg 1.20.14, glibc 2.43, libglvnd 1.7.0, NVIDIA 340.108, kernel
5.4.302, 64-bit + 32-bit).

## Libraries

```
# server GLX module (NVIDIA, not Xorg's stock module)
/usr/lib64/xorg/modules/extensions/libglx.so -> libglx.so.340.108

# client OpenGL
/usr/lib64/libGL.so.1     -> libGL.so.340.108
/usr/lib64/libGLX.so.0    -> libGL.so.340.108   (glvnd shim)
/usr/lib64/libOpenGL.so.0 -> libGL.so.340.108   (glvnd shim)

# 32-bit equivalents
/usr/lib32/libGL.so.1     -> libGL.so.340.108
/usr/lib32/libGLX.so.0    -> libGL.so.340.108
/usr/lib32/libOpenGL.so.0 -> libGL.so.340.108
```

`libGL.so.340.108` is NVIDIA's monolithic GL/GLX library from the 340.108
installer. The glvnd shims are required because 340.108 has no
`libGLX_nvidia.so.0` vendor backend.

## TLS

`libnvidia-tls.so.340.108` (64 and 32) must be the `tls/` variant
(0 syscalls). The installer's default variant calls
`arch_prctl(ARCH_SET_FS, ...)` and breaks glibc 2.43.

The good variants are kept in:

```
/usr/local/share/nvidia-340-tls/64/libnvidia-tls.so.340.108
/usr/local/share/nvidia-340-tls/32/libnvidia-tls.so.340.108
```

## Update safety

`/usr/local/sbin/nvidia-340-fixups.sh`
: Re-runs `ldconfig` first, then recreates every symlink above and checks the
  TLS variants. Idempotent.

`/etc/init.d/nvidia-340-fixups`
: OpenRC service, `before display-manager`, enabled in the default runlevel.
  Runs the fixup on every boot.

`/etc/portage/bashrc`
: Portage `postinst` hook. After a merge of `media-libs/libglvnd`,
  `media-libs/mesa`, `x11-base/xorg-server`, `x11-drivers/nvidia-drivers`,
  `x11-apps/mesa-progs`, or `media-libs/freeglut`, it runs the fixup with
  `NVIDIA_FIXUP_SKIP_LDCONFIG=1` (Portage has just done `ldconfig`; the
  symlinks must be created afterwards). Logs to
  `/var/log/nvidia-340-fixups.log`.

`/etc/portage/package.mask/xorg-server-121`
: `>=x11-base/xorg-server-1.21` — 340.108 supports server ABI 24 only.

## Verification

```sh
# links
ls -l /usr/lib64/libGL.so.1 /usr/lib64/libGLX.so.0 \
      /usr/lib64/libOpenGL.so.0 \
      /usr/lib64/xorg/modules/extensions/libglx.so

# TLS variant (expect 0 for both)
objdump -d /usr/lib64/libnvidia-tls.so.340.108 | grep -c syscall
objdump -d /usr/lib32/libnvidia-tls.so.340.108 | grep -c syscall

# live 3D
DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority glxinfo -B
DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority glxgears

# kernel module
lsmod | grep nvidia
```

Expected:

```
direct rendering: Yes
OpenGL renderer string: GeForce 8600M GT/PCIe/SSE2
OpenGL version string: 3.3.0 NVIDIA 340.108
```

## Rollback

The original files are backed up by the installer and by hand:

```
/root/libnvidia-tls.so.340.108.orig-fshack
/root/libnvidia-tls.so.340.108.i386.orig-fshack
/root/libGL.so.1.glvnd.bak
/root/libGLX.so.0.glvnd.bak
```

To remove the shims:

```sh
ln -sfn libGL.so.1.7.0 /usr/lib64/libGL.so.1
ln -sfn libGLX.so.0.0.0 /usr/lib64/libGLX.so.0
ln -sfn libOpenGL.so.0.0.0 /usr/lib64/libOpenGL.so.0
ldconfig
```

(Exact glvnd symlink names depend on the installed libglvnd version.)

## Upgrade notes

* Rebuilding `media-libs/libglvnd` is safe: the postinst hook restores the
  shims. This was tested.
* A **NVIDIA driver reinstall** via the `.run` may put back the FS-hack
  `libnvidia-tls` and replace `libglx.so`. Run:

  ```sh
  /usr/local/sbin/nvidia-340-fixups.sh
  nvidia/install-tls-variant.sh
  ```

  or simply reboot (the boot service runs the fixup).
* Do not let Xorg go above 1.20.x; the mask enforces this.
* Do not build Xorg/glibc with `-j6` on the 2-core/2.9 GB machine.
  Use `MAKEOPTS="-j2"` and `nice`.
