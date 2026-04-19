#!/usr/bin/env bash
# Generates the iLockin.xcodeproj from project.yml using XcodeGen,
# installing XcodeGen via Homebrew if necessary.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is required. Install it from https://brew.sh and re-run."
        exit 1
    fi
    echo "Installing XcodeGen via Homebrew..."
    brew install xcodegen
fi

echo "Generating iLockin.xcodeproj from project.yml..."
xcodegen generate

echo ""
echo "Done. Open the project with:"
echo "    open iLockin.xcodeproj"
