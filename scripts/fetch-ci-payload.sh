#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
usage:
  fetch-ci-payload.sh <arch> <kernel-url> <ramfs-artifact-id> <output-dir>

Downloads the kernel release tarball and the dsvz-ramfs workflow artifact used
by CI boot smoke tests.  The script writes two path files in <output-dir>:

  kernel.path
  initrd.path
USAGE
}

if [ "$#" -ne 4 ]; then
    usage >&2
    exit 2
fi

arch="$1"
kernel_url="$2"
ramfs_artifact_id="$3"
out_dir="$4"

ramfs_repo="${RAMFS_REPOSITORY:-yoshi3jp/dsvz-ramfs}"
api_version="${GITHUB_API_VERSION:-2026-03-10}"
artifact_api_url="https://api.github.com/repos/${ramfs_repo}/actions/artifacts/${ramfs_artifact_id}/zip"

case "$arch" in
    x86_64|arm64)
        ;;
    *)
        echo "unsupported arch: $arch" >&2
        exit 2
        ;;
esac

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "required command not found: $1" >&2
        exit 1
    fi
}

need_command curl
need_command find
need_command tar
need_command unzip
need_command zstd

rm -rf "$out_dir"
mkdir -p "$out_dir/kernel" "$out_dir/ramfs"

kernel_archive="$out_dir/kernel.tar.zst"
ramfs_zip="$out_dir/ramfs-artifact.zip"

echo "Downloading kernel from $kernel_url"
curl -fL --retry 3 --retry-delay 5 \
    -o "$kernel_archive" \
    "$kernel_url"

echo "Extracting kernel archive"
zstd -dc "$kernel_archive" | tar -xf - -C "$out_dir/kernel"

echo "Downloading ramfs artifact ${ramfs_artifact_id} from ${ramfs_repo}"
curl_args=(
    -fL
    --retry 3
    --retry-delay 5
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: ${api_version}"
)

if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=( -H "Authorization: Bearer ${GITHUB_TOKEN}" )
fi

curl "${curl_args[@]}" \
    -o "$ramfs_zip" \
    "$artifact_api_url"

echo "Extracting ramfs artifact"
unzip -q "$ramfs_zip" -d "$out_dir/ramfs"

find_first_matching_file() {
    local root="$1"
    shift

    local pattern
    for pattern in "$@"; do
        local match
        match="$(find "$root" -type f -name "$pattern" -print | sort | head -n 1)"
        if [ -n "$match" ]; then
            printf '%s\n' "$match"
            return 0
        fi
    done

    return 1
}

case "$arch" in
    x86_64)
        kernel_path="$(find_first_matching_file \
            "$out_dir/kernel" \
            bzImage \
            'vmlinuz*' \
            'kernel*x86_64*' \
            'kernel*amd64*' \
            'kernel*' || true)"
        ;;
    arm64)
        kernel_path="$(find_first_matching_file \
            "$out_dir/kernel" \
            Image \
            'Image-*' \
            'vmlinuz*' \
            'kernel*arm64*' \
            'kernel*aarch64*' \
            'kernel*' || true)"
        ;;
esac

initrd_path="$(find_first_matching_file \
    "$out_dir/ramfs" \
    '*.cpio.gz' \
    '*.cpio.xz' \
    '*.cpio.zst' \
    '*.cpio' \
    '*initramfs*' \
    '*ramfs*' || true)"

if [ -z "${kernel_path:-}" ] || [ ! -f "$kernel_path" ]; then
    echo "failed to locate extracted kernel image" >&2
    echo "extracted files:" >&2
    find "$out_dir/kernel" -maxdepth 4 -type f -print >&2
    exit 1
fi

if [ -z "${initrd_path:-}" ] || [ ! -f "$initrd_path" ]; then
    echo "failed to locate extracted ramfs/initrd image" >&2
    echo "extracted files:" >&2
    find "$out_dir/ramfs" -maxdepth 4 -type f -print >&2
    exit 1
fi

printf '%s\n' "$kernel_path" > "$out_dir/kernel.path"
printf '%s\n' "$initrd_path" > "$out_dir/initrd.path"

echo "Selected kernel: $kernel_path"
echo "Selected initrd: $initrd_path"
