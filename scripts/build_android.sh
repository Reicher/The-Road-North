#!/bin/sh

set -eu

GODOT_BIN="${GODOT_BIN:-/Users/robin.reicher/Downloads/Godot 2.app/Contents/MacOS/Godot}"
PRESET="${ANDROID_EXPORT_PRESET:-Android APK (Debug)}"
OUTPUT="${ANDROID_APK_OUTPUT:-build/android/road-to-karlskoga-debug.apk}"

mkdir -p "$(dirname "$OUTPUT")"
"$GODOT_BIN" --headless --path . --export-debug "$PRESET" "$OUTPUT"

printf "\nBuilt %s\n" "$OUTPUT"
