# Signing

`dsvz` uses Apple's Virtualization.framework. A binary that launches virtual
machines must be signed with the `com.apple.security.virtualization` entitlement
before the VM launch path is usable.

The repository keeps that entitlement in:

```text
dsvz.entitlements
```

For developer and CI builds, ad-hoc signing is sufficient for the debug CLI:

```sh
swift build
scripts/sign-debug.sh .build/debug/dsvz
```

The signing helper intentionally does not build the project. This matters
because Linux workstations may be used for editing and Git operations, but this
project is macOS-specific and should be built by macOS hosts or GitHub Actions
macOS runners.

The signed debug binary can be inspected with:

```sh
codesign --display --entitlements :- .build/debug/dsvz
```

The entitlement is added before VM launch support so the CI path proves that the
binary can be signed on both Intel and Apple Silicon macOS runners.
