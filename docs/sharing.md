# Host directory sharing

`dsvz run` exposes one writable macOS directory to the Droidspaces guest using
Apple Virtualization.framework's VirtIO-FS support.

## Run options

```text
--share <directory>
--share-tag <tag>
```

`--share` is required. `dsvz` creates the directory if it does not already
exist and rejects an existing non-directory path.

`--share-tag` defaults to `dsdata`. The tag is the guest-visible VirtIO-FS
identifier, not a host pathname. `dsvz` validates the tag through
`VZVirtioFileSystemDeviceConfiguration.validateTag` before creating the VM.

The current Droidspaces initramfs expects the default tag and mounts it as:

```text
macOS directory selected by --share
  -> VirtIO-FS tag dsdata
    -> /mnt/host in the Droidspaces initramfs
```

## Local bundle

The local boot-test bundle supplies `./DroidspacesData` as the default share.
`run-local-smoke.sh` creates the following host-visible layout before launch:

```text
DroidspacesData/
├── Cache/
├── Config/
├── Containers/
├── Images/
├── Logs/
└── RootfsTarballs/
```

At this stage the directories establish the stable host/guest storage contract
only. The next container-deployment stage will place a rootfs tarball in
`RootfsTarballs/`, have the initramfs import it into a sparse Linux image under
`Images/`, and then start it through Droidspaces.

## Example

```sh
./dsvz run \
  --kernel ./kernel \
  --initrd ./initramfs.cpio.gz \
  --machine-id ./MachineIdentifier \
  --share ./DroidspacesData \
  --share-tag dsdata \
  --cpus 2 \
  --memory 1024 \
  --cmdline 'console=hvc0 init=/init panic=-1'
```

The guest needs VirtIO-FS support (`CONFIG_VIRTIO_FS`) and FUSE filesystem
support (`CONFIG_FUSE_FS`) in the kernel. The current Project 1 VZ kernel has
been validated for the native VZ boot path; this commit validates its host-share
attachment path.
