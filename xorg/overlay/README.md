# Xorg 1.20.14 overlay

This directory contains the exact ebuild and patches used on the test
machine. It is not a full overlay; copy the package into your local overlay:

```sh
sudo mkdir -p /var/db/repos/local/x11-base
sudo cp -a xorg/overlay/x11-base/xorg-server /var/db/repos/local/x11-base/
sudo mkdir -p /var/db/repos/local/profiles
echo local | sudo tee /var/db/repos/local/profiles/repo_name
```

Install with GLX enabled (the ebuild uses `use_enable !minimal glx`, so do not
set `USE=minimal`):

```sh
sudo emerge --oneshot =x11-base/xorg-server-1.20.14
```

The `Manifest` is included. If Portage complains that it is stale (for example
after editing the ebuild), regenerate it:

```sh
sudo ebuild /var/db/repos/local/x11-base/xorg-server/xorg-server-1.20.14.ebuild manifest
```

The ebuild downloads `xorg-server-1.20.14.tar.xz` from x.org; network access is
needed on the first build.

## Why 1.20.14

NVIDIA 340.108 supports Xorg server ABI 24 (Xorg 1.20.x). Xorg 1.21+ (ABI 25)
will not load the driver. The included mask blocks it:

```
system/package.mask/xorg-server-121 -> /etc/portage/package.mask/
```

## After installing Xorg

The server GLX module must be NVIDIA's:

```
/usr/lib64/xorg/modules/extensions/libglx.so -> libglx.so.340.108
```

The `nvidia-340-fixups` service (and the Portage hook) re-asserts that link
after every Xorg upgrade.

Sample config files are in `xorg/conf/`:

* `20-nvidia.conf` — minimal `Driver "nvidia"`.
* `10-glx-load.conf` — explicit `Load "glx"` (optional; this build loads it by
  default).
