# Build and run

Install Xcode 27.3 through `xcodes`. For simulator tests, install a matching iOS runtime. Editing targets also needs `xcodegen`.

Set `DEVELOPER_DIR` to your Xcode installation, then build:

```sh
git clone https://github.com/kesku/duo-workspace.git DuoWorkspace
cd DuoWorkspace
export DEVELOPER_DIR=/Applications/Xcode-27.3.0-Beta.app/Contents/Developer
Scripts/build.sh
```

The script tests the packages and builds both apps. To run client tests too, choose a device from `xcrun simctl list devices available` and set its identifier:

```sh
export DUO_TEST_DESTINATION='platform=iOS Simulator,id=<UUID>'
Scripts/build.sh
```

The current build is checked on Apple Silicon with macOS 27.3. The deployment targets are iOS 17 and macOS 14; those older systems still need testing.

Edit `project.yml` when adding files or changing targets, then run `xcodegen generate`.

## Signing and installation

The first build creates a host-signing identity in `.secrets/`. The build script and Xcode reuse it. The simulator client uses ad-hoc signing. These builds don't need an Apple Developer account.

Keep `.secrets/` when moving the checkout, or point `DUO_SIGNING_DIR` at the existing signing folder. If signing files are damaged or incomplete, the build stops. Restore the originals; replacing the identity requires new Mac permissions.

For a physical device, open `DuoWorkspace.xcodeproj`, choose your team and a unique client bundle identifier in Signing & Capabilities, then run. Personal Team installs need periodic reprovisioning. Keep personal signing settings out of commits.

Allow Duo Workspace Host under Screen & System Audio Recording and Accessibility. Reopen the host if macOS asks. Native touch also needs virtual HID access; see [its setup](NativeTouch.md#running-it).

## Testing

Run `/usr/bin/python3 Scripts/test-local-signing.py` to check signing with disposable keychains.

The Debug host's Open input test window records clicks, releases and text. Choose Use as Display when the host and simulator run on the same Mac, so keyboard input targets the remote workspace.

On the same Mac, mute the simulator's playback to avoid feedback. Keep an input device selected for microphone tests. Close Device Hub when testing a physical phone.

Use `--simulate-keychain-write-failure` to test persistence errors, then relaunch without it.

Build output goes in `.artifacts/`, or the folder set by `DUO_BUILD_ROOT`. Keep `.secrets/`, Keychain records and the revocation journal when cleaning up.

## Duo Microphone

The host bundles a Core Audio input-device installer. Choose **Install microphone device** in Duo Workspace Host and approve the macOS installer. The plug-in is installed at `/Library/Audio/Plug-Ins/HAL/DuoMicrophone.driver`; installation briefly restarts Mac audio. It doesn't change the Mac's default input.

`Scripts/build-microphone-driver.sh` builds the universal driver and installer. `Scripts/test-microphone-driver.sh` checks the driver with address and undefined-behavior sanitizers. The installed-device check is `Tests/DriverTests/MicrophoneDeviceCheck.c`.

To uninstall, remove `DuoMicrophone.driver` from that HAL folder with administrator access and restart Mac audio or reboot.
