# TelegramPPC

TelegramPPC is a native Cocoa Telegram client for Mac OS X 10.5 Leopard on PowerPC Macs. It is written in Objective-C++ and uses TDLib for Telegram protocol access.

<img width="942" height="684" alt="image" src="https://github.com/user-attachments/assets/64116cb1-c424-408f-9e9a-f8236432b3e0" />

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

## Target

- Mac OS X 10.5 Leopard
- PowerPC
- MacPorts-based build environment
- A C++20-capable MacPorts compiler, tested with `g++-mp-14`

This is not an official Telegram client.

## Dependencies

The build expects these to be available on the target Mac:

- Cocoa and OpenGL system frameworks
- TDLib from MacPorts
- FFmpeg libraries available through `pkg-config`
- `nlohmann/json.hpp`
- Optional `libppcvoip.dylib`

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

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=/opt/local/bin/g++-mp-14 \
  -DCMAKE_OBJCXX_COMPILER=/opt/local/bin/g++-mp-14
cmake --build build
```

The app bundle is written to:

```text
build/TelegramPPC.app
```

Clean build output with:

```sh
rm -rf build
```

## License

TelegramPPC is released under the Boost Software License 1.0. TDLib is also licensed under the Boost Software License 1.0.

See `THIRD_PARTY_NOTICES.md` for dependency notes.
