# Droidspaces VZ

`dsvz` is a macOS command-line runner for booting a Droidspaces-oriented
Linux kernel and Droidspaces initramfs using Apple's Virtualization.framework.

The intended architecture is:

```text
macOS
  -> Virtualization.framework
    -> Linux kernel
      -> Droidspaces initramfs
        -> Droidspaces-managed containers
```

The first development target is a CLI test harness. A GUI application can be
added after the kernel, initramfs, shared directory, and VM lifecycle contracts
are stable.

## Development policy

This project is macOS-specific. Linux hosts may be used for editing and Git
operations, but local Linux builds are not meaningful. GitHub Actions macOS
runners are used as the initial compiler/test environment.

## Current stage

The current implementation provides a SwiftPM CLI with direct Linux
kernel/initramfs boot support:

```sh
dsvz help
dsvz version
dsvz run --kernel ./bzImage --initrd ./droidspaces-initramfs.cpio.gz
```

Directory sharing, networking, persistent disks, and plist configuration are
intentionally left for later commits. CI downloads architecture-matched kernel
and ramfs artifacts, packages them with the signed CLI, and publishes local
boot-test bundles for real Mac hardware.

## Build on macOS

```sh
swift build
```

## Sign the debug binary on macOS

A binary that launches Virtualization.framework VMs must be signed with the
`com.apple.security.virtualization` entitlement. The repository provides the
entitlement file and a debug signing helper:

```sh
scripts/sign-debug.sh .build/debug/dsvz
```

See [`docs/signing.md`](docs/signing.md) for details. See [`docs/running.md`](docs/running.md) for the current VM launch flow. See [`docs/ci-boot.md`](docs/ci-boot.md) for CI payload packaging and local boot testing.

## Planned stages

1. Add SwiftPM CLI skeleton and CI.
2. Add entitlement and signing documentation.
3. Add direct Linux kernel/initramfs boot.
4. Download kernel/ramfs artifacts and publish local boot-test bundles.
5. Add `VZSingleDirectoryShare`.
6. Add NAT networking.
7. Add plist-based configuration.
