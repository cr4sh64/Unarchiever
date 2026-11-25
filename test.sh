#!/bin/bash
# Vérifie Extractor avec de vraies archives.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -swift-version 5 Sources/Extractor.swift Tests/main.swift -o build/selfcheck
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
build/selfcheck "$PWD/Vendor/7zz" "$WORK"
