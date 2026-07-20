#!/bin/sh

set -eu

SETTINGS_FILE="${GODOT_EDITOR_SETTINGS:-$HOME/Library/Application Support/Godot/editor_settings-4.6.tres}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

if [ ! -x "$JAVA_HOME/bin/java" ]; then
	printf "Java SDK not found at %s\n" "$JAVA_HOME" >&2
	exit 1
fi

if [ ! -x "$ANDROID_HOME/platform-tools/adb" ]; then
	printf "Android SDK not found at %s\n" "$ANDROID_HOME" >&2
	exit 1
fi

if [ ! -f "$SETTINGS_FILE" ]; then
	printf "Godot editor settings not found at %s\n" "$SETTINGS_FILE" >&2
	exit 1
fi

if pgrep -f 'Godot.*--editor|Godot.*The-Road-North|Godot 2.app/Contents/MacOS/Godot' >/dev/null 2>&1; then
	printf "Close Godot before running this script; the open editor will overwrite the setting.\n" >&2
	exit 1
fi

sed -i '' \
	-e "s#export/android/java_sdk_path = \".*\"#export/android/java_sdk_path = \"$JAVA_HOME\"#" \
	-e "s#export/android/android_sdk_path = \".*\"#export/android/android_sdk_path = \"$ANDROID_HOME\"#" \
	"$SETTINGS_FILE"

printf "Configured Godot Android editor settings:\n"
printf "Java SDK: %s\n" "$JAVA_HOME"
printf "Android SDK: %s\n" "$ANDROID_HOME"
