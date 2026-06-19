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
