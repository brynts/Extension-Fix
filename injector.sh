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

echo "🔍 Extracting executable name..."
BINARY_NAME=$(plutil -extract CFBundleExecutable xml1 -o - "$INFO_PLIST" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')

if [ -z "$BINARY_NAME" ]; then
    echo "❌ Error: Could not determine executable name from Info.plist!"
    exit 1
fi

APP_PATH=$(dirname "$INFO_PLIST")
APP_BINARY="$APP_PATH/$BINARY_NAME"

if [ ! -f "$APP_BINARY" ]; then
    echo "❌ Error: Mach-O binary not found at $APP_BINARY"
    exit 1
fi

echo "✅ Found binary: $APP_BINARY"

echo "🔧 Injecting dylib..."
echo "ℹ️ Checking insert_dylib..."
ls -l "$INSERT_DYLIB"
file "$INSERT_DYLIB"

echo "ℹ️ Running insert_dylib with debugging..."
"$INSERT_DYLIB" --verbose "$EXTENSION_LIB" "$APP_BINARY" --inplace 2>&1 | tee inject_dylib.log

if [ $? -eq 0 ]; then
    echo "✅ Dylib successfully injected!"
else
    echo "❌ Error: insert_dylib failed!"
    cat inject_dylib.log
    exit 1
fi

# Ambil BundleID & Versi dari Info.plist untuk rename IPA
BUNDLE_ID=$(plutil -extract CFBundleIdentifier xml1 -o - "$INFO_PLIST" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tr -d ' ')
APP_VERSION=$(plutil -extract CFBundleShortVersionString xml1 -o - "$INFO_PLIST" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tr -d ' ')

IPA_INJECTED="packages/${BUNDLE_ID}_injected.ipa"

echo "📦 Repacking Injected IPA..."
cd extracted_ipa && zip -qr "../$IPA_INJECTED" * && cd ..

echo "ℹ️ IPA_INJECTED: $IPA_INJECTED"
ls -l "$IPA_INJECTED"

echo "🔧 Running Azule to inject into frameworks..."
IPA_PATCHED="packages/${BUNDLE_ID}_patched.ipa"

azule -m -n "${BUNDLE_ID}_patched" -i "$IPA_INJECTED" -f "$(pwd)/Extension/ExtensionFix.dylib" -o "packages"

if [ $? -eq 0 ]; then
    echo "✅ Azule successfully injected into frameworks!"
else
    echo "❌ Error injecting with Azule!"
    exit 1
fi

# Pastikan file hasil Azule sesuai nama yang diinginkan
mv "packages/${BUNDLE_ID}_patched.ipa" "$IPA_PATCHED"

echo "🧹 Cleaning up..."
rm -rf extracted_ipa inject_dylib.log

echo "🎉 Patch completed!"
echo "🔹 Original: packages/downloaded.ipa"
echo "🔹 Injected (insert_dylib): $IPA_INJECTED"
echo "🔹 Patched (Azule): $IPA_PATCHED"