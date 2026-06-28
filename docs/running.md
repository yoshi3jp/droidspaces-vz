# Running a Droidspaces VM

`dsvz run` boots a Linux kernel and Droidspaces initramfs directly using
Apple's Virtualization.framework.

The current VM launch path attaches a serial console, entropy, one writable
host directory shared with the guest through VirtIO-FS, and one VirtIO network
device attached to macOS NAT. Persistent virtual disks and plist configuration
remain staged for later commits. CI uses this command with architecture-matched
kernel and ramfs artifacts to package local boot-test bundles for real Mac
hardware.

## Example

```sh
swift build
scripts/sign-debug.sh .build/debug/dsvz

.build/debug/dsvz run \
  --kernel ./bzImage \
  --initrd ./droidspaces-initramfs.cpio.gz \
  --machine-id ./MachineIdentifier \
  --share ./DroidspacesData \
  --share-tag dsdata \
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

## Host directory sharing

`dsvz run` requires `--share <directory>`. It creates that directory when it is
missing and exposes it read-write through a VirtIO-FS device. The default tag is
`dsdata`, which the Droidspaces initramfs mounts at `/mnt/host`.

See [`sharing.md`](sharing.md) for the host/guest storage contract and bundle
layout.

## Guest expectations

The initramfs should provide an `/init` entry point, print to the VirtIO console,
and mount the `dsdata` VirtIO-FS tag at `/mnt/host`. The default kernel command
line is:

```text
console=hvc0 init=/init
```

A minimal initramfs can use `/dev/hvc0` as its console and does not need a root
block device for this first stage.

## Guest networking

`dsvz` presents one VirtIO network device backed by
`VZNATNetworkDeviceAttachment`. The device gets a locally administered MAC
address generated for the VM launch. The `dsvz` startup output prints that MAC
address with the `network:` line.

The host-side attachment only exposes the guest NIC. The initramfs must bring
that NIC up, obtain an address with DHCP, and configure resolver state before
Droidspaces depends on external connectivity. See [`networking.md`](networking.md)
for the host/guest boundary and first-boot checks.
