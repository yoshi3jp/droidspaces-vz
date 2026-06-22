#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
usage:
  ci-boot-smoke.sh <dsvz-binary> <kernel> <initrd> <log-file> [seconds]

Runs a short Virtualization.framework boot smoke test.  The VM is allowed to run
for the requested number of seconds, then the dsvz process is terminated if it
is still alive.  The test passes only if the log shows that the VM started and
that the guest kernel produced recognizable console output.
USAGE
}

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    usage >&2
    exit 2
fi

binary="$1"
kernel="$2"
initrd="$3"
log_file="$4"
seconds="${5:-30}"

if [ ! -x "$binary" ]; then
    echo "dsvz binary is not executable: $binary" >&2
    exit 1
fi

if [ ! -f "$kernel" ]; then
    echo "kernel image not found: $kernel" >&2
    exit 1
fi

if [ ! -f "$initrd" ]; then
    echo "initrd image not found: $initrd" >&2
    exit 1
fi

rm -f "$log_file"
share_dir="$(dirname "$log_file")/DroidspacesData"
mkdir -p "$share_dir"

echo "Starting CI boot smoke test for ${seconds}s"
"$binary" run \
    --kernel "$kernel" \
    --initrd "$initrd" \
    --machine-id "$(dirname "$log_file")/MachineIdentifier" \
    --share "$share_dir" \
    --share-tag dsdata \
    --cpus 2 \
    --memory 1024 \
    --cmdline 'console=hvc0 init=/init panic=-1' \
    >"$log_file" 2>&1 &

pid="$!"
status=0

sleep "$seconds"

if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Stopping CI boot smoke test process $pid"
    kill "$pid" >/dev/null 2>&1 || true
    wait "$pid" || true
else
    wait "$pid" || status="$?"
fi

echo "----- dsvz boot log -----"
cat "$log_file"
echo "----- end dsvz boot log -----"

if [ "$status" -ne 0 ]; then
    echo "dsvz exited before timeout with status $status" >&2
    exit "$status"
fi

grep -q 'VM started' "$log_file" || {
    echo "VM did not reach the started state" >&2
    exit 1
}

grep -E -q 'Linux version|Kernel command line|Command line:|Droidspaces|BusyBox|initramfs|Freeing unused kernel' "$log_file" || {
    echo "guest kernel/initramfs did not produce recognizable console output" >&2
    exit 1
}
