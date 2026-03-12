# 🛠️ Buildroot for [aa-proxy-rs](https://github.com/aa-proxy/aa-proxy-rs)

This repository contains the build system (based on Buildroot) used for building [aa-proxy](https://github.com/aa-proxy/aa-proxy-rs) images.

## 🚀 Quick Start (Example: Raspberry Pi Zero 2 W)

```bash
git clone --recurse-submodules https://github.com/aa-proxy/buildroot
cd buildroot
./docker-dev build
./docker-dev rpi02w
```

## 🐳 Interactive development (container shell)
If you want more control, you can enter an interactive shell inside the development container:

```
./docker-dev shell
```
Once inside, you can manually run builds like this:

```
./build-image.sh rpi02w
```
Useful for testing, debugging, or tweaking the environment without restarting the whole process.

## 📦 Available Configurations
All supported board/device configurations can be found here:  
👉 [external/configs](https://github.com/aa-proxy/buildroot/tree/main/external/configs) on GitHub

## 💾 Output Image
After a successful build, the final SD card image (for above example) will be located at:

```
buildroot/output/rpi02w/images/sdcard.img
```
You can flash this image directly to an SD card using dd, [balenaEtcher](https://etcher.balena.io/) or whatever flash tool you like.

## ⚡ Fast replace of `aa-proxy-rs` in an existing `sdcard.img`
If you only changed `aa-proxy-rs` and want to avoid a full rebuild, you can inject a prebuilt binary directly into an existing image:

```bash
mkdir -p combine
cp output/<board>/images/sdcard.img combine/
cp /path/to/aa-proxy-rs combine/
./tools/inject-aa-proxy-rs.sh combine
```

The script mounts the Linux partition inside `sdcard.img` and replaces `/usr/bin/aa-proxy-rs` in-place.

## 🧰 Troubleshooting AA mass-storage mode
If you see errors like these on target:

- `not enough free space to create mass image`
- `could not mount mass image via loop device`

then there are **two separate requirements**:

1. `dosfstools` must be present on target (`mkfs.fat`/`mkfs.vfat`) so the mass image can be formatted.
2. `/data` must have enough free space for `music_mass.img` (the error itself shows required vs available).

This repository now enables target-side `dosfstools` via Buildroot (`BR2_PACKAGE_DOSFSTOOLS=y` in `external/configs/common.part`).

If free space is still low, reduce `MASS_IMAGE_SIZE_MB` (as the runtime hint suggests) or increase available space on the `/data` partition in your image layout.
