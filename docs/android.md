# Run on Android

The Android export targets 64-bit ARM phones and locks the game to portrait
orientation. Godot's debug keystore is sufficient for local device testing.

## One-time setup on macOS

Use Godot 4.6.3, matching the project's configured engine version.

1. Install Java and the Android command-line tools:

   ```sh
   brew install openjdk@17
   brew install --cask android-commandlinetools
   ```

2. Install the required Android SDK packages:

   ```sh
   sdkmanager --sdk_root="$HOME/Library/Android/sdk" \
     "platform-tools" \
     "build-tools;35.0.1" \
     "platforms;android-35" \
     "cmdline-tools;latest" \
     "cmake;3.10.2.4988404" \
     "ndk;28.1.13356709"
   sdkmanager --licenses
   ```

3. In Godot, open **Editor Settings > Export > Android** and set:

   - Android SDK Path: `~/Library/Android/sdk`
   - Java SDK Path:
     `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`

   Alternatively, close Godot and run:

   ```sh
   scripts/configure_godot_android.sh
   ```

4. In Godot, open **Editor > Manage Export Templates** and install the export
   templates for Godot 4.6.3.

Verify the setup from the repository root:

```sh
scripts/check_android_setup.sh
```

## Connect the Samsung phone

1. On the phone, enable **Developer options** by tapping **Build number** seven
   times under **Settings > About phone > Software information**.
2. Enable **USB debugging** under **Settings > Developer options**.
3. Connect the phone over USB and accept the debugging authorization prompt.
4. Confirm that the phone appears under `adb devices`.

## Run from Godot

Open the project in Godot 4.6.3. With the phone connected, click the Android
device icon in the editor toolbar to export, install, and run the debug build.
The export dialog contains the **Android APK (Debug)** preset.

To build an APK without installing it:

```sh
scripts/build_android.sh
```

To install the built APK on a connected phone:

```sh
"$HOME/Library/Android/sdk/platform-tools/adb" install -r \
  build/android/road-to-karlskoga-debug.apk
```
