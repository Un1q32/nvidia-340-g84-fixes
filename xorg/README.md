# Xorg notes

Use **Xorg 1.20.x**. NVIDIA 340.108 supports server ABI 24; Xorg 1.21+
(ABI 25) is not supported. The tested version is 1.20.14.

## Build

The tested ebuild and patches are included in `overlay/` (see
`overlay/README.md`). Build with GLX enabled (the default; do not pass
`EXTRA_ECONF=--disable-glx`). The server may
contain both a built-in GLX and load NVIDIA's `libglx.so`; you may see
`Initializing extension GLX` twice in the log. That is harmless — the
NVIDIA module is the one that provides the fbconfigs.

The NVIDIA `.run` installer provides:

```
/usr/lib64/xorg/modules/extensions/libglx.so.340.108
/usr/lib64/xorg/modules/drivers/nvidia_drv.so
```

and replaces the `libglx.so` symlink. The fixup script re-asserts:

```
/usr/lib64/xorg/modules/extensions/libglx.so -> libglx.so.340.108
```

`/etc/X11/xorg.conf.d/10-glx-load.conf` is optional; the server loads `glx`
by default in this build. A minimal config is fine:

```
Section "Module"
    Load "glx"
EndSection
```

## Mask

`system/package.mask/xorg-server-121` contains:

```
>=x11-base/xorg-server-1.21
```

Install it as `/etc/portage/package.mask/xorg-server-121`.

## Log lines that mean success

```
(II) NVIDIA GLX Module  340.108
(II) Initializing extension GLX
```

At `-logverbose 10` the driver also logs `NVIDIA(0): GLX visuals set up`.

## Verification

```
DISPLAY=:0 XAUTHORITY=/home/uniq/.Xauthority glxinfo -B
direct rendering: Yes
OpenGL renderer string: GeForce 8600M GT/PCIe/SSE2
OpenGL version string: 3.3.0 NVIDIA 340.108
```

The server reports 284 fbconfigs. `tools/glxq.c` prints the raw server GLX
version/vendor/fbconfig count without going through libglvnd's client library.
