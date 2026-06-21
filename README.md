<p align="center">
  <img src="Resources/Sailplane.png" width="128" height="128" alt="Sailplane icon" />
</p>

<h1 align="center">Sailplane</h1>

<p align="center">
  <a href="https://github.com/doctashay/telegram-ppc/actions/workflows/release.yml"><img alt="ppc macOS" src="https://img.shields.io/github/actions/workflow/status/doctashay/telegram-ppc/release.yml?branch=main&job=Build%20ppc&label=ppc%20macOS" /></a>
  <a href="https://github.com/doctashay/telegram-ppc/actions/workflows/release.yml"><img alt="i386 macOS" src="https://img.shields.io/github/actions/workflow/status/doctashay/telegram-ppc/release.yml?branch=main&job=Build%20i386&label=i386%20macOS" /></a>
  <a href="https://github.com/doctashay/telegram-ppc/actions/workflows/release.yml"><img alt="x86_64 macOS" src="https://img.shields.io/github/actions/workflow/status/doctashay/telegram-ppc/release.yml?branch=main&job=Build%20x86_64&label=x86_64%20macOS" /></a>
  <a href="https://github.com/doctashay/telegram-ppc/actions/workflows/release.yml"><img alt="arm64 macOS" src="https://img.shields.io/github/actions/workflow/status/doctashay/telegram-ppc/release.yml?branch=main&job=Build%20arm64&label=arm64%20macOS" /></a>
</p>

<p align="center">
  <a href="https://github.com/doctashay/telegram-ppc/releases/latest"><img alt="latest release" src="https://img.shields.io/github/v/release/doctashay/telegram-ppc?label=release" /></a>
  <a href="https://app.codacy.com/gh/doctashay/telegram-ppc/dashboard"><img alt="Codacy grade" src="https://app.codacy.com/project/badge/Grade/da6139ff95a444feb866ad252037c3f9" /></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/github/license/doctashay/telegram-ppc" /></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-10.4%2B-blue" />
</p>

## Project Overview
Sailplane is an unofficial Telegram client for macOS, written in Objective-C++ with TDLib handling the Telegram protocol.

The project focuses on keeping Telegram usable on older Macs without splitting the codebase away from modern macOS support. The same client is intended to build for PowerPC, Intel, and Apple Silicon, with compatibility work kept close to the platform code. A full compatibility chart can be found [here](#compatibility).



## Features

- Telegram authorization through TDLib
- Chat list and message history
- Send, edit, delete, and reply to messages
- Basic reaction support
- File attachment sending
- Profile photos, inline images, and image preview overlay
- Link previews
- Twemoji-based emoji rendering
- Inline video playback through FFmpeg

## Releases

Tagged releases include a universal DMG along with separate builds for each architecture. If you are not sure which one to use, start with the universal build.

| File | Use this for |
| --- | --- |
| `Sailplane-*-universal.dmg` | Most users |
| `Sailplane-*-ppc.dmg` | PowerPC Macs |
| `Sailplane-*-i386.dmg` | 32-bit Intel Macs |
| `Sailplane-*-x86_64.dmg` | 64-bit Intel Macs |
| `Sailplane-*-arm64.dmg` | Apple Silicon Macs |

Download the latest release here: https://github.com/doctashay/telegram-ppc/releases/latest

## Supported Targets

- Mac OS X 10.4 Tiger or later
- PowerPC, Intel and Apple Silicon Macs 

<details>
<summary>Architecture support by macOS version</summary>

This chart describes Sailplane's intended platform support by macOS release and CPU architecture.

CI currently verifies PowerPC and i386 builds against a 10.5 SDK, while x86_64 and arm64 are verified against a modern macOS SDK. If a listed configuration fails to build or run, please open an issue.

| macOS version | PowerPC | i386 | x86_64 | arm64 |
| --- | --- | --- | --- | --- |
| Mac OS X 10.4 Tiger | ✓ | ✓ | x | x |
| Mac OS X 10.5 Leopard | ✓ | ✓ | ✓ | x |
| Mac OS X 10.6 Snow Leopard | x | ✓ | ✓ | x |
| Mac OS X 10.7 Lion | x | ✓ | ✓ | x |
| OS X 10.8 Mountain Lion | x | ✓ | ✓ | x |
| OS X 10.9 Mavericks | x | ✓ | ✓ | x |
| OS X 10.10 Yosemite | x | ✓ | ✓ | x |
| OS X 10.11 El Capitan | x | ✓ | ✓ | x |
| macOS 10.12 Sierra | x | ✓ | ✓ | x |
| macOS 10.13 High Sierra | x | ✓ | ✓ | x |
| macOS 10.14 Mojave | x | ✓ | ✓ | x |
| macOS 10.15 Catalina | x | x | ✓ | x |
| macOS 11 Big Sur | x | x | ✓ | ✓ |
| macOS 12 Monterey | x | x | ✓ | ✓ |
| macOS 13 Ventura | x | x | ✓ | ✓ |
| macOS 14 Sonoma | x | x | ✓ | ✓ |
| macOS 15 Sequoia | x | x | ✓ | ✓ |
| macOS 26 Tahoe | x | x | ✓ | ✓ |
| macOS 27 Golden Gate | x | x | ✓ | ✓ |

</details>

## Project Layout
Right now, the main Cocoa app is in `Sources`, with the entry point in `main.mm`. Most of the client is in here: windows, table views, chat/message rendering, auth, media views, and compatibility helpers. A lot of the user-facing behavior is split across the `AppDelegate` categories and the supporting view/model files in that folder.

Sailplane talks to Telegram through TDLib. That integration is in `Sources/TelegramBridge.*`, and CMake handles finding/linking TDLib. `TelegramCredentials.example.h` shows the credentials header the build expects; the real `TelegramCredentials.h` is not tracked. 
  
You can learn more about registering a Telegram app here: https://core.telegram.org/api/obtaining_api_id

The `scripts` folder has the build/release helpers: cross builds, universal binary assembly, dependency config, and CI checks. GitHub Actions workflows live in `.github/workflows`. The workflows are partially dependent on a Docker toolchain image which is maintained separately from this repo for now.

The codebase uses manual Objective-C memory management instead of ARC because Sailplane still targets older macOS versions where ARC is not available.

## Dependencies

Currently, the build expects these to be available on the target Mac:

- Cocoa and OpenGL system frameworks
- TDLib 
- FFmpeg libraries available through `pkg-config`
- `nlohmann/json.hpp`

Install the MacPorts dependencies with:

```sh
sudo port install cmake gcc14 tdlib ffmpeg nlohmann-json
```

CMake finds dependencies through the MacPorts prefix, `/opt/local` by default, and copies the MacPorts `libtdjson.dylib` into the app bundle.

## Local Configuration

Create `TelegramCredentials.h` from the example:

```objc
#pragma once

#define TELEGRAM_API_ID 0
#define TELEGRAM_API_HASH @"replace-with-your-telegram-api-hash"
```

## Build

  For a normal local build, configure the project with CMake and point it at a compiler that can build Objective-C++:

  ```sh
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=/opt/local/bin/g++-mp-14 \
    -DCMAKE_OBJCXX_COMPILER=/opt/local/bin/g++-mp-14
  cmake --build build
  ```

  The app bundle is written to:

  `build/Sailplane.app`

  **Legacy Compatibility Note**

  Sailplane still targets older macOS releases, so the default deployment target is 10.4. Tiger app bundles declare `LSMinimumSystemVersion` as 10.4.

  When building against Apple's `MacOSX10.4u.sdk` on Leopard with the MacPorts GCC toolchain, you may need to pass a
  readable startup object if the SDK's `crt1.o` fails to link:

  ```sh
  cmake -S . -B build-tiger -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_SYSROOT=/Developer/SDKs/MacOSX10.4u.sdk \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.4 \
    -DTELEGRAM_PPC_STARTUP_OBJECT=/usr/lib/crt1.o \
    -DCMAKE_CXX_COMPILER=/opt/local/bin/g++-mp-14 \
    -DCMAKE_OBJCXX_COMPILER=/opt/local/bin/g++-mp-14
  cmake --build build-tiger
  ```

  Release builds are handled by the CI pipeline and a separate Darwin cross-compile Docker image. That path builds the architecture slices individually, then assembles a universal app. If you have any suggestions for improving this workflow, feel free to open an isuse. 

## License

Sailplane is released under the Boost Software License 1.0, as is TDLib. See `THIRD_PARTY_NOTICES.md` for dependency notes.
