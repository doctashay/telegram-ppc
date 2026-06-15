cmake_minimum_required(VERSION 3.20)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.5" CACHE STRING "Minimum macOS deployment target")
set(CMAKE_OSX_ARCHITECTURES "ppc" CACHE STRING "Target architecture")
set(MACPORTS_PREFIX "/opt/local" CACHE PATH "MacPorts installation prefix")

project(TelegramPPC LANGUAGES CXX OBJCXX)

list(PREPEND CMAKE_PREFIX_PATH "${MACPORTS_PREFIX}")

find_package(PkgConfig REQUIRED)
pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET
  libavcodec
  libavformat
  libswscale
  libavutil
)

find_path(NLOHMANN_JSON_INCLUDE_DIR
  NAMES nlohmann/json.hpp
  PATHS "${MACPORTS_PREFIX}/include"
  REQUIRED
)

find_library(TDJSON_LIBRARY
  NAMES tdjson
  PATHS "${MACPORTS_PREFIX}/lib" "${MACPORTS_PREFIX}/libexec/tdlib/lib"
)

if(NOT TDJSON_LIBRARY)
  message(FATAL_ERROR "TDLib was not found in ${MACPORTS_PREFIX}. Install it with: sudo port install tdlib")
endif()

find_library(PPCVOIP_LIBRARY
  NAMES ppcvoip
  PATHS "${MACPORTS_PREFIX}/lib"
)

find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(OPENGL_FRAMEWORK OpenGL REQUIRED)

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/TelegramCredentials.h")
  message(FATAL_ERROR
    "Missing TelegramCredentials.h. Copy TelegramCredentials.example.h and set TELEGRAM_API_ID/TELEGRAM_API_HASH."
  )
endif()

set(TELEGRAM_PPC_SOURCES
  Sources/AppDelegate.mm
  Sources/AppDelegate+Auth.mm
  Sources/AppDelegate+Calls.mm
  Sources/AppDelegate+Media.mm
  Sources/AppDelegate+TDLib.mm
  Sources/AppDelegate+Tables.mm
  Sources/ChatCell.mm
  Sources/Common.mm
  Sources/EmojiText.mm
  Sources/FoundationHelpers.mm
  Sources/ImageDrawing.mm
  Sources/MediaViews.mm
  Sources/MessageCell.mm
  Sources/MessageContent.mm
  Sources/TelegramBridge.mm
  Sources/VideoPlayerView.mm
)

set(TELEGRAM_PPC_HEADERS
  Sources/AppDelegate.h
  Sources/AppDelegatePrivate.h
  Sources/ChatCell.h
  Sources/Common.h
  Sources/EmojiText.h
  Sources/FoundationHelpers.h
  Sources/ImageDrawing.h
  Sources/MediaViews.h
  Sources/MessageCell.h
  Sources/MessageContent.h
  Sources/TelegramBridge.h
  Sources/VideoPlayerView.h
)

set(TELEGRAM_PPC_RESOURCES
  Resources/TelegramPPC.icns
  Resources/TelegramPPC.png
  Resources/TelegramPPC.svg
  Resources/phone_24.png
  Resources/refresh_24.png
)

add_executable(TelegramPPC MACOSX_BUNDLE
  main.mm
  ${TELEGRAM_PPC_SOURCES}
  ${TELEGRAM_PPC_HEADERS}
  ${TELEGRAM_PPC_RESOURCES}
)

set_source_files_properties(${TELEGRAM_PPC_HEADERS}
  PROPERTIES HEADER_FILE_ONLY TRUE
)

set_source_files_properties(${TELEGRAM_PPC_RESOURCES}
  PROPERTIES MACOSX_PACKAGE_LOCATION Resources
)

set_target_properties(TelegramPPC PROPERTIES
  OUTPUT_NAME TelegramPPC
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED YES
  CXX_EXTENSIONS YES
  OBJCXX_STANDARD 20
  OBJCXX_STANDARD_REQUIRED YES
  OBJCXX_EXTENSIONS YES
)

target_include_directories(TelegramPPC PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${NLOHMANN_JSON_INCLUDE_DIR}"
)

target_compile_options(TelegramPPC PRIVATE
  -mno-powerpc64
  -fno-strict-aliasing
  -fobjc-call-cxx-cdtors
  -fobjc-exceptions
  -Wall
  -Wextra
)

target_link_libraries(TelegramPPC PRIVATE
  "${COCOA_FRAMEWORK}"
  "${OPENGL_FRAMEWORK}"
  dl
  PkgConfig::FFMPEG
)

add_custom_command(TARGET TelegramPPC POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E make_directory "$<TARGET_BUNDLE_CONTENT_DIR:TelegramPPC>/Frameworks"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${TDJSON_LIBRARY}" "$<TARGET_BUNDLE_CONTENT_DIR:TelegramPPC>/Frameworks/libtdjson.dylib"
  VERBATIM
)

if(PPCVOIP_LIBRARY)
  add_custom_command(TARGET TelegramPPC POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${PPCVOIP_LIBRARY}" "$<TARGET_BUNDLE_CONTENT_DIR:TelegramPPC>/Frameworks/libppcvoip.dylib"
    VERBATIM
  )
endif()
