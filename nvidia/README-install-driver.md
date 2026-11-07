# Installing the base NVIDIA 340.108 driver

This repository does **not** contain the proprietary NVIDIA driver. Get the
official 340.108 `.run` from NVIDIA:

```
https://us.download.nvidia.com/XFree86/Linux-x86_64/340.108/NVIDIA-Linux-x86_64-340.108.run
```

Size: 70,165,522 bytes
SHA256: `c671d4f1b7c09bc1af079b98b447adb06d704b04f802f7045a611fa50133b71b`

The convenience script downloads, verifies, and extracts it:

```sh
sudo ./fetch-driver.sh
# -> /root/NVIDIA-Linux-x86_64-340.108
```

## Order of operations

The 340.108 installer's kernel-module build fails on GCC 16, and its default
userspace install breaks glibc 2.43 (the FS-hack `libnvidia-tls`) and the
glvnd setup. Use the split flow:

```sh
# 1. stop the desktop
sudo rc-service display-manager stop

# 2. install userspace only
sudo NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 ./install-userspace.sh

# 3. build the kernel module from the unmodified source
sudo NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 \
     ../kernel/build-nvidia-340-module.sh

# 4. install the TLS fix, glvnd shims, boot service, Portage hook, Xorg mask
sudo NVIDIA_SRC=/root/NVIDIA-Linux-x86_64-340.108 ../install.sh
```

Step 2 invokes:

```
nvidia-installer --no-kernel-module --no-x-check --no-nouveau-check \
                 --no-questions --accept-license
```

It installs `nvidia_drv.so`, `libnvidia-glcore`, `libglx.so.340.108`, the
32-bit libraries, and the default (bad) `libnvidia-tls`. Step 4 replaces the
TLS library and re-points the libraries.

## Xorg

Use Xorg 1.20.x. The ebuild and patches are in `../xorg/overlay/`; see
`../xorg/overlay/README.md`.

## Kernel

The kernel module source comes from the `.run` tree. The script uses
`/usr/src/linux`; the tested kernel was 5.4.302. `intel_iommu=off` is required
on this MacBook for the NVIDIA EVO path.

## Why not run the .run directly?

Running the `.run` normally:

* tries to build the kernel module (fails with GCC 16),
* installs the FS-hack `libnvidia-tls` (crashes glibc 2.43 at GLX init),
* may replace `libGL.so.1`/`libglx.so` with versions that do not work with
  libglvnd 1.7.

The split flow avoids all three. If you do run it normally, run
`../../install.sh` afterwards; it repairs the TLS and library wiring.
