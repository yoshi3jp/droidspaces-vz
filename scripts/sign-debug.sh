#!/bin/sh
set -eu

usage() {
    echo "usage: $0 <path-to-dsvz-binary>" >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

BINARY=$1
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
ENTITLEMENTS="$ROOT/dsvz.entitlements"

if [ ! -f "$BINARY" ]; then
    echo "error: binary not found: $BINARY" >&2
    exit 1
fi

if [ ! -f "$ENTITLEMENTS" ]; then
    echo "error: entitlement file not found: $ENTITLEMENTS" >&2
    exit 1
fi

codesign \
    --force \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    "$BINARY"

codesign --verify --verbose "$BINARY"
