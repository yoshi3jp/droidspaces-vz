#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
usage:
  package-ci-bundle.sh <arch> <dsvz-binary> <payload-dir> <output-dir>

Creates a downloadable local boot-test bundle containing:

  dsvz
  kernel
  initramfs.cpio.gz
  run-local-smoke.sh
  DroidspacesData/
  README.local.txt
USAGE
}

if [ "$#" -ne 4 ]; then
    usage >&2
    exit 2
fi

arch="$1"
binary="$2"
payload_dir="$3"
out_dir="$4"

case "$arch" in
    x86_64|arm64)
        ;;
    *)
        echo "unsupported arch: $arch" >&2
        exit 2
        ;;
esac

if [ ! -x "$binary" ]; then
    echo "dsvz binary not found or not executable: $binary" >&2
    exit 1
fi

if [ ! -f "$payload_dir/kernel.path" ] || [ ! -f "$payload_dir/initrd.path" ]; then
    echo "payload path files are missing in $payload_dir" >&2
    exit 1
fi

kernel_path="$(cat "$payload_dir/kernel.path")"
initrd_path="$(cat "$payload_dir/initrd.path")"

if [ ! -f "$kernel_path" ]; then
    echo "kernel image not found: $kernel_path" >&2
    exit 1
fi

if [ ! -f "$initrd_path" ]; then
    echo "initramfs image not found: $initrd_path" >&2
    exit 1
fi

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "required command not found: $1" >&2
        exit 1
    fi
}

need_command shasum
need_command tar

rm -rf "$out_dir"
mkdir -p "$out_dir"

staging="$out_dir/dsvz-macos-$arch"
mkdir -p "$staging"

cp "$binary" "$staging/dsvz"
cp "$kernel_path" "$staging/kernel"
cp "$initrd_path" "$staging/initramfs.cpio.gz"
chmod +x "$staging/dsvz"

mkdir -p "$staging/DroidspacesData"
cat > "$staging/DroidspacesData/README.txt" <<'EOF_SHARE'
Droidspaces host data directory
===============================

This directory is shared read-write with the guest through VirtIO-FS using the
dsdata tag. The Droidspaces initramfs mounts it at /mnt/host.

Commit 7 establishes this share boundary. A later commit will populate
RootfsTarballs/, Images/, Containers/, Config/, Logs/, and Cache/ as part of
the first-container deployment flow.
EOF_SHARE

cat > "$staging/run-local-smoke.sh" <<'RUNNER'
#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ "$(uname -m)" = "x86_64" ]; then
    expected_arch=x86_64
elif [ "$(uname -m)" = "arm64" ]; then
    expected_arch=arm64
else
    echo "unsupported Mac architecture: $(uname -m)" >&2
    exit 1
fi

memory=${DSVZ_MEMORY:-1024}
cpus=${DSVZ_CPUS:-2}
cmdline=${DSVZ_CMDLINE:-console=hvc0 init=/init panic=-1}
share=${DSVZ_SHARE:-./DroidspacesData}
share_tag=${DSVZ_SHARE_TAG:-dsdata}

mkdir -p "$share"

for directory in Config RootfsTarballs Images Containers Logs Cache; do
    mkdir -p "$share/$directory"
done

echo "Starting local Droidspaces VZ smoke test"
echo "  host arch: $expected_arch"
echo "  memory:    ${memory} MiB"
echo "  cpus:      ${cpus}"
echo "  share:     ${share}"
echo "  share tag: ${share_tag}"
echo "  cmdline:   ${cmdline}"
echo ""

exec ./dsvz run \
    --kernel ./kernel \
    --initrd ./initramfs.cpio.gz \
    --machine-id ./MachineIdentifier \
    --share "$share" \
    --share-tag "$share_tag" \
    --memory "$memory" \
    --cpus "$cpus" \
    --cmdline "$cmdline"
RUNNER
chmod +x "$staging/run-local-smoke.sh"

cat > "$staging/README.local.txt" <<EOF_README
Droidspaces VZ local boot-test bundle
=====================================

Architecture: $arch

Contents:

  dsvz                 signed debug CLI built by GitHub Actions
  kernel               Droidspaces VZ Linux kernel image
  initramfs.cpio.gz    Droidspaces initramfs image
  MachineIdentifier    created on first run by dsvz when missing
  DroidspacesData/     writable VirtIO-FS host share
  run-local-smoke.sh   convenience launcher

Basic local test:

  ./run-local-smoke.sh

If the archive was downloaded through a browser and macOS quarantined it, clear
that attribute from the extracted directory before running the test:

  xattr -dr com.apple.quarantine .

You can override the VM size and kernel command line:

  DSVZ_MEMORY=2048 DSVZ_CPUS=2 ./run-local-smoke.sh
  DSVZ_SHARE=/path/to/DroidspacesData ./run-local-smoke.sh
  DSVZ_SHARE_TAG=dsdata ./run-local-smoke.sh
  DSVZ_CMDLINE='console=hvc0 init=/init panic=-1' ./run-local-smoke.sh

The default DroidspacesData directory is exposed read-write to the guest over
VirtIO-FS with the dsdata tag. The initramfs mounts it at /mnt/host.

This bundle is intended for local Mac hardware. GitHub-hosted macOS runners are
used to compile, sign, and package the binary, but VM boot testing is performed
locally.
EOF_README

archive="$out_dir/dsvz-macos-$arch.tar.gz"
tar -C "$out_dir" -czf "$archive" "dsvz-macos-$arch"
shasum -a 256 "$archive" > "$archive.sha256"

echo "Created $archive"
echo "Created $archive.sha256"
