# Running a Droidspaces VM

`dsvz run` boots a Linux kernel and Droidspaces initramfs directly using
Apple's Virtualization.framework.

The initial VM launch support is intentionally minimal. It attaches a serial
console to the terminal and supplies entropy, but it does not yet attach host
directory sharing, networking, persistent disks, or a plist configuration file.
Those features are staged for later commits. CI uses this command with
architecture-matched kernel and ramfs artifacts to perform a short boot smoke
test on macOS runners.

## Example

```sh
swift build
scripts/sign-debug.sh .build/debug/dsvz

.build/debug/dsvz run \
  --kernel ./bzImage \
  --initrd ./droidspaces-initramfs.cpio.gz \
  --machine-id ./MachineIdentifier \
  --cpus 2 \
  --memory 1024 \
  --cmdline 'console=hvc0 init=/init'
```

The binary must be signed with `com.apple.security.virtualization` before it
can launch a VM. See [`signing.md`](signing.md).

## Machine identifier

`dsvz run` creates a `VZGenericMachineIdentifier` for the generic Linux VM
platform. If `--machine-id <path>` is supplied and the file does not yet exist,
`dsvz` creates it. If the file already exists, `dsvz` reuses it.

For disposable initramfs tests the option may be omitted, in which case an
ephemeral identifier is used for that launch. Local boot-test bundles use a
`MachineIdentifier` file in the extracted bundle directory so repeated runs use
the same generic platform identity.

## Guest expectations

The initramfs should provide an `/init` entry point and should print to the
VirtIO console. The default kernel command line is:

```text
console=hvc0 init=/init
```

A minimal initramfs can use `/dev/hvc0` as its console and does not need a root
block device for this first stage.
