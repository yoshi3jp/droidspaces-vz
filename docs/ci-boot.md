# CI payload packaging and local boot testing

The CI workflow compiles and signs the `dsvz` CLI on both macOS runner
architectures, downloads the matching Droidspaces VZ kernel and ramfs payloads,
and publishes local boot-test bundles.

GitHub-hosted macOS runners are currently treated as a build and packaging
environment, not as a reliable Virtualization.framework boot-test environment.
The boot test is expected to run on real local Mac hardware.

## Inputs

Kernel release assets are downloaded from `yoshi3jp/vz-kernel`:

```text
https://github.com/yoshi3jp/vz-kernel/releases/download/v6.12.93/kernel-x86_64-6.12.93.tar.zst
https://github.com/yoshi3jp/vz-kernel/releases/download/v6.12.93/kernel-arm64-6.12.93.tar.zst
```

Ramfs inputs are downloaded from the `yoshi3jp/dsvz-ramfs` workflow artifact
API by artifact ID:

```text
x86_64: 7731337868
arm64:  7731381874
```

The browser artifact URLs are not treated as stable file URLs. The workflow uses
the GitHub Actions artifact API endpoint instead.

## Output bundles

Each architecture produces a downloadable archive:

```text
dsvz-macos-x86_64.tar.gz
dsvz-macos-arm64.tar.gz
```

The archive contains:

```text
dsvz
kernel
initramfs.cpio.gz
run-local-smoke.sh
DroidspacesData/
README.local.txt
```

CI uploads these as workflow artifacts. On pushes to `main` or `master`, CI also
publishes or replaces the `ci-latest` prerelease so the latest build can be
downloaded from the GitHub Releases page.

## Local test

Download the archive matching the Mac architecture, extract it, and run:

```sh
./run-local-smoke.sh
```

The launcher uses `./DroidspacesData` as the default writable host share. It is
attached to the guest as VirtIO-FS tag `dsdata`, which the Droidspaces
initramfs mounts at `/mnt/host`.

If the archive was downloaded through a browser and macOS quarantined it, clear
that attribute from the extracted directory:

```sh
xattr -dr com.apple.quarantine .
```

## Helper scripts

```text
scripts/fetch-ci-payload.sh
```

Downloads and extracts the architecture-matched kernel and ramfs. It writes:

```text
ci-payload/kernel.path
ci-payload/initrd.path
```

```text
scripts/package-ci-bundle.sh
```

Packages the signed `dsvz` binary and fetched kernel/initramfs into a local
boot-test archive.

```text
scripts/ci-boot-smoke.sh
```

Kept for future/self-hosted runner use. It attempts to run `dsvz run` for a
short time and inspect the serial console log. It is no longer invoked by the
default GitHub-hosted macOS CI workflow.
