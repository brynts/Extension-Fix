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

echo "🔍 Finding main binary..."
APP_BINARY=$(find extracted_ipa/Payload -type f -perm +111 -exec file {} \; | grep "Mach-O.*executable" | cut -d: -f1 | head -n 1)

if [ -z "$APP_BINARY" ]; then
    echo "❌ Error: No valid Mach-O binary found!"
    exit 1
fi

echo "✅ Found binary: $APP_BINARY"
echo "🔧 Injecting dylib..."
"$INSERT_DYLIB" "$EXTENSION_LIB" "$APP_BINARY" --inplace

echo "📦 Repacking IPA..."
cd extracted_ipa && zip -qr "../packages/downloaded_patched.ipa" * && cd ..

echo "🧹 Cleaning up..."
rm -rf extracted_ipa

echo "🎉 Patch completed: packages/downloaded_patched.ipa"
