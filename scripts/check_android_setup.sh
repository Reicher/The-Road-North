#!/bin/sh

set -eu

GODOT_BIN="${GODOT_BIN:-/Users/robin.reicher/Downloads/Godot 2.app/Contents/MacOS/Godot}"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="${ADB:-$ANDROID_HOME/platform-tools/adb}"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"

failed=0

check_file() {
	if [ -e "$1" ]; then
		printf "OK: %s\n" "$2"
	else
		printf "MISSING: %s (%s)\n" "$2" "$1"
		failed=1
	fi
}

check_file "$GODOT_BIN" "Godot 4.6 executable"
check_file "$ANDROID_HOME" "Android SDK"
check_file "$ADB" "adb"
check_file "$ANDROID_HOME/build-tools/35.0.1" "Android build tools 35.0.1"
check_file "$ANDROID_HOME/platforms/android-35" "Android platform 35"
check_file "$ANDROID_HOME/cmake/3.10.2.4988404" "CMake 3.10.2"
check_file "$ANDROID_HOME/ndk/28.1.13356709" "Android NDK r28b"
check_file "$JAVA_HOME/bin/java" "Java 17"

templates_dir="$HOME/Library/Application Support/Godot/export_templates"
if find "$templates_dir" -maxdepth 1 -type d -name '4.6.3.stable' 2>/dev/null | grep -q .; then
	printf "OK: Godot 4.6.3 export templates\n"
else
	printf "MISSING: Godot 4.6.3 export templates\n"
	failed=1
fi

if [ "$failed" -ne 0 ]; then
	printf "\nSee docs/android.md for setup instructions.\n"
	exit 1
fi

printf "\nAndroid export prerequisites are installed.\n"
printf "Connected devices:\n"
"$ADB" devices
