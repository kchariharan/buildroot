#!/usr/bin/env bash
set -euo pipefail

# Fast post-build injector for aa-proxy-rs into an existing Buildroot sdcard.img.
# Expected default layout:
#   combine/
#     ├── sdcard.img
#     └── aa-proxy-rs

SCRIPT_NAME=$(basename "$0")
COMBINE_DIR="${1:-combine}"
IMAGE_PATH="${2:-$COMBINE_DIR/sdcard.img}"
BINARY_PATH="${3:-$COMBINE_DIR/aa-proxy-rs}"
TARGET_PATH="/usr/bin/aa-proxy-rs"

usage() {
  cat <<USAGE
Usage: $SCRIPT_NAME [combine_dir] [sdcard_img] [aa_proxy_binary]

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME ./combine
  $SCRIPT_NAME ./combine ./combine/sdcard.img ./combine/aa-proxy-rs

This script will:
  1) attach the image as a loop device,
  2) mount Linux partitions one-by-one,
  3) find the rootfs partition containing $TARGET_PATH,
  4) replace the binary and keep executable permissions.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

for cmd in losetup mount umount stat install sync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found." >&2
    exit 1
  fi
done

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "Error: image not found: $IMAGE_PATH" >&2
  exit 1
fi

if [[ ! -f "$BINARY_PATH" ]]; then
  echo "Error: binary not found: $BINARY_PATH" >&2
  exit 1
fi

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Warning: $BINARY_PATH is not marked executable; forcing mode 0755 on install."
fi

LOOP_DEV=""
MOUNT_DIR=""
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" -eq 1 && -n "$MOUNT_DIR" ]]; then
    sudo umount "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi

  if [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]]; then
    rmdir "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi

  if [[ -n "$LOOP_DEV" ]]; then
    sudo losetup -d "$LOOP_DEV" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

LOOP_DEV=$(sudo losetup --find --show --partscan "$IMAGE_PATH")
echo "Attached $IMAGE_PATH to $LOOP_DEV"

FOUND_TARGET=0

for part in ${LOOP_DEV}p*; do
  [[ -b "$part" ]] || continue

  fstype=$(sudo blkid -o value -s TYPE "$part" 2>/dev/null || true)
  case "$fstype" in
    ext2|ext3|ext4|btrfs|xfs)
      ;;
    *)
      continue
      ;;
  esac

  MOUNT_DIR=$(mktemp -d)
  if ! sudo mount "$part" "$MOUNT_DIR"; then
    rmdir "$MOUNT_DIR"
    MOUNT_DIR=""
    continue
  fi
  MOUNTED=1

  if [[ -f "$MOUNT_DIR$TARGET_PATH" || -d "$MOUNT_DIR/usr/bin" ]]; then
    echo "Using partition $part ($fstype)"
    sudo install -m 0755 "$BINARY_PATH" "$MOUNT_DIR$TARGET_PATH"
    sudo sync
    FOUND_TARGET=1

    size=$(stat -c %s "$BINARY_PATH")
    echo "Injected aa-proxy-rs ($size bytes) -> $TARGET_PATH"

    sudo umount "$MOUNT_DIR"
    MOUNTED=0
    rmdir "$MOUNT_DIR"
    MOUNT_DIR=""
    break
  fi

  sudo umount "$MOUNT_DIR"
  MOUNTED=0
  rmdir "$MOUNT_DIR"
  MOUNT_DIR=""
done

if [[ "$FOUND_TARGET" -ne 1 ]]; then
  echo "Error: could not find a suitable Linux rootfs partition in $IMAGE_PATH" >&2
  exit 1
fi

echo "Done. You can now flash: $IMAGE_PATH"
