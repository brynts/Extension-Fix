#!/bin/bash
set -e

IPA_PATH="$1"

if [ -z "$IPA_PATH" ]; then
    echo "Usage: $0 <ipa_path>"
    exit 1
fi

EXTENSION_LIB="Extension/ExtensionFix.dylib"
INSERT_DYLIB="src/bin/insert_dylib"

if [ ! -f "$INSERT_DYLIB" ]; then
    echo "Error: insert_dylib not found. Build it first."
    exit 1
fi

if [ ! -f "$EXTENSION_LIB" ]; then
    echo "Error: ExtensionFix.dylib not found."
    exit 1
fi

echo "Extracting IPA..."
unzip -q "$IPA_PATH" -d extracted_ipa

APP_BINARY=$(find extracted_ipa/Payload -type f -perm +111 -exec file {} \; | grep Mach-O | cut -d: -f1)

if [ -z "$APP_BINARY" ]; then
    echo "Error: No valid Mach-O binary found."
    exit 1
fi

echo "Injecting dylib..."
"$INSERT_DYLIB" --inplace "@executable_path/ExtensionFix.dylib" "$APP_BINARY"

echo "Repacking IPA..."
cd extracted_ipa && zip -qr "../packages/downloaded_patched.ipa" * && cd ..

echo "Cleaning up..."
rm -rf extracted_ipa

echo "Patch completed: packages/downloaded_patched.ipa"
