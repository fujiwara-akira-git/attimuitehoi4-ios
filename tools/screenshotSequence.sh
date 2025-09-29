#!/usr/bin/env bash

# シミュレータでアプリを起動して決め打ちでスクリーンショットを取る簡易スクリプト
# 注意: simctl でのボタン操作は制限があるため、このスクリプトは主にアプリ起動とスクリーンショット取得を自動化します。
# より複雑なUI操作には `xcrun simctl ui` や `osascript` を組み合わせる必要があります。

set -eu

APP_BUNDLE_ID="com.akiralabs.Attimuitehoi4-ios"
DEVICE_NAME="iPhone 16 Pro"
OS_VERSION="26.0"

SIM_DEVICE=$(xcrun simctl list devices available | grep "${DEVICE_NAME} (" | grep "${OS_VERSION}" | head -n1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')
if [ -z "$SIM_DEVICE" ]; then
  echo "Simulator device not found for ${DEVICE_NAME} iOS ${OS_VERSION}"
  exit 1
fi

echo "Using simulator: $SIM_DEVICE"

# Boot the simulator
xcrun simctl boot "$SIM_DEVICE" || true
xcrun simctl shutdown "$SIM_DEVICE" >/dev/null 2>&1 || true
xcrun simctl boot "$SIM_DEVICE"

# Install app (assumes build has been placed in derived data as Debug-iphonesimulator)
APP_PATH=$(ls ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator/*.app | head -n1)
if [ -z "$APP_PATH" ]; then
  echo "Built .app not found in DerivedData. Please build the project first."
  exit 1
fi

echo "Installing app: $APP_PATH"
xcrun simctl install "$SIM_DEVICE" "$APP_PATH"

# Launch app
xcrun simctl launch "$SIM_DEVICE" "$APP_BUNDLE_ID" --console || true

# Wait a moment for app to reach initial screen
sleep 2

# Screenshots dir
OUT_DIR="$(pwd)/../Screenshots"
mkdir -p "$OUT_DIR"

# Capture multiple screenshots at specific delays to cover states
xcrun simctl io "$SIM_DEVICE" screenshot "$OUT_DIR/screen1_initial.png"
sleep 1
xcrun simctl io "$SIM_DEVICE" screenshot "$OUT_DIR/screen2_after_initial.png"
sleep 2
xcrun simctl io "$SIM_DEVICE" screenshot "$OUT_DIR/screen3_janken.png"
sleep 3
xcrun simctl io "$SIM_DEVICE" screenshot "$OUT_DIR/screen4_aimm.png"
sleep 2
xcrun simctl io "$SIM_DEVICE" screenshot "$OUT_DIR/screen5_result.png"

echo "Screenshots saved to $OUT_DIR"

# Optionally shutdown
# xcrun simctl shutdown "$SIM_DEVICE"

exit 0
