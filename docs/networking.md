# Networking

`dsvz` presents one VirtIO network device to every VM launch. The device uses
Apple Virtualization.framework's `VZNATNetworkDeviceAttachment`, so macOS
performs network address translation for guest traffic and routes it through the
host's available external connection.

```text
Linux guest VirtIO NIC
  -> macOS NAT attachment
    -> macOS host network connection
      -> outside networks
```

The NAT attachment is the initial connectivity mode. It does not require the
`com.apple.vm.networking` entitlement and does not make guest services directly
reachable as independent LAN services. Bridged networking is a later optional
mode.

## Scope boundary

This repository configures the host-side virtual NIC only. It does not configure
the guest operating system. The Droidspaces initramfs must do the following
before any workload needs network access:

1. Discover the non-loopback VirtIO network interface.
2. Bring the interface up.
3. Obtain an IPv4 lease and default route with DHCP.
4. Install resolver configuration.

Until that initramfs work lands, the expected first-boot result is a visible
non-loopback network interface with no configured address.

## First-boot checks

From the guest initramfs shell, inspect the device before changing kernel
configuration:

```sh
ip -br link
ip -br addr
cat /proc/net/dev
dmesg | grep -Ei 'virtio|virtio_net|net'
```

Interpret the result as follows:

| Observation | Likely boundary to investigate |
| --- | --- |
| Only `lo` is present | macOS VM configuration or the guest VirtIO-net driver |
| A non-loopback interface has no address | Guest initramfs link/DHCP setup |
| An address exists but there is no default route | Guest DHCP script or route setup |
| External IP access works but names fail | Guest resolver configuration |

The `dsvz` launch log prints the selected locally administered MAC address. Use
that value to correlate the Virtualization.framework configuration with guest
boot logs.
