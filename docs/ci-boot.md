# CI boot smoke test

The CI workflow does more than compile the Swift CLI.  It also downloads the
current Droidspaces VZ kernel and ramfs artifacts for the runner architecture
and performs a short Virtualization.framework boot smoke test.

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

The browser artifact URLs are not treated as stable file URLs.  The workflow
uses the GitHub Actions artifact API endpoint instead.

## Helper scripts

```text
scripts/fetch-ci-payload.sh
```

Downloads and extracts the architecture-matched kernel and ramfs.  It writes:

```text
ci-payload/kernel.path
ci-payload/initrd.path
```

```text
scripts/ci-boot-smoke.sh
```

Runs `dsvz run` for a short time, captures the serial console log, terminates
the VM process if it is still running, and checks that:

1. `dsvz` reached the `VM started` state.
2. The guest produced recognizable kernel/initramfs console output.

## Scope

This is still a smoke test.  It does not yet validate host directory sharing,
networking, rootfs import, sparse image handling, or Droidspaces container
startup.  Those should be added after the basic kernel/initramfs boot path is
stable under macOS CI.
