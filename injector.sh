#!/bin/bash
set -e

IPA_PATH="$1"

if [ -z "$IPA_PATH" ]; then
    echo "❌ Error: No IPA file specified!"
    exit 1
fi

EXTENSION_LIB="Extension/ExtensionFix.dylib"
INSERT_DYLIB="src/bin/insert_dylib"

if [ ! -f "$INSERT_DYLIB" ]; then
    echo "❌ Error: insert_dylib not found at $INSERT_DYLIB"
    exit 1
fi

if [ ! -f "$EXTENSION_LIB" ]; then
    echo "❌ Error: ExtensionFix.dylib not found at $EXTENSION_LIB"
    exit 1
fi

echo "📦 Extracting IPA..."
rm -rf extracted_ipa && mkdir extracted_ipa
unzip -q "$IPA_PATH" -d extracted_ipa

echo "🔍 Finding Info.plist..."
INFO_PLIST=$(find extracted_ipa/Payload -maxdepth 2 -type f -name "Info.plist" | head -n 1)

if [ -z "$INFO_PLIST" ]; then
    echo "❌ Error: No Info.plist found!"
    exit 1
fi

echo "✅ Found Info.plist at $INFO_PLIST"

APP_PATH=$(dirname "$INFO_PLIST")

echo "🔍 Finding all Mach-O binaries in $APP_PATH..."
MACHO_FILES=$(find "$APP_PATH" -type f -exec file {} \; | grep "Mach-O" | cut -d: -f1)

if [ -z "$MACHO_FILES" ]; then
    echo "❌ Error: No Mach-O binaries found!"
    exit 1
fi

echo "✅ Found $(echo "$MACHO_FILES" | wc -l) Mach-O binaries."

for BINARY in $MACHO_FILES; do
    echo "🔧 Injecting dylib into $BINARY..."
    "$INSERT_DYLIB" "$EXTENSION_LIB" "$BINARY" --inplace
    echo "✅ Injected into $BINARY"
done

echo "📦 Repacking IPA..."
cd extracted_ipa && zip -qr "../packages/downloaded_patched.ipa" * && cd ..

echo "🧹 Cleaning up..."
rm -rf extracted_ipa

echo "🎉 Patch completed: packages/downloaded_patched.ipa"