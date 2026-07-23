#!/bin/sh

set -eu

if [ -z "${GODOT_BIN:-}" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT_BIN="godot"
	elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
	elif [ -x "/Users/robin.reicher/Downloads/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT_BIN="/Users/robin.reicher/Downloads/Godot.app/Contents/MacOS/Godot"
	else
		printf "Godot binary not found. Set GODOT_BIN to the Godot 4.6.3 executable.\n" >&2
		exit 1
	fi
fi

PRESET="${ANDROID_EXPORT_PRESET:-Android APK (Debug)}"
OUTPUT="${ANDROID_APK_OUTPUT:-build/android/the-road-north-debug.apk}"

mkdir -p "$(dirname "$OUTPUT")"
"$GODOT_BIN" --headless --path . --export-debug "$PRESET" "$OUTPUT"

printf "\nBuilt %s\n" "$OUTPUT"
