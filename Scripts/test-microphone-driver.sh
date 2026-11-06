#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/build-environment.sh
build="$DUO_BUILD_ROOT/microphone"
mkdir -p "$build"
xcrun clang -std=c11 -O1 -g -fsanitize=address,undefined -Wno-unused-parameter \
    -I Sources/DuoMicrophoneBridge/include Tests/DriverTests/MicrophoneDriverTests.c \
    Drivers/DuoMicrophone/DuoMicrophone.c Drivers/DuoMicrophone/MicrophoneBuffer.c \
    -framework CoreAudio -framework CoreFoundation -o "$build/driver-tests"
"$build/driver-tests"
