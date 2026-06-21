cmake_minimum_required(VERSION 3.20)

set(CMAKE_OSX_DEPLOYMENT_TARGET "10.4" CACHE STRING "Minimum macOS deployment target")
set(CMAKE_OSX_ARCHITECTURES "" CACHE STRING "Target architecture; leave empty for the compiler default")
set(MACPORTS_PREFIX "" CACHE PATH "Optional MacPorts installation prefix; used only as a dependency search hint")
set(TELEGRAM_PPC_DEPENDENCY_ROOTS "" CACHE STRING "Semicolon-separated dependency prefixes to search before system paths")
set(TELEGRAM_PPC_MIN_SYSTEM_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}" CACHE STRING "Minimum system version shown by the app bundle")
set(TELEGRAM_PPC_CPU_TARGET "auto" CACHE STRING "CPU target: auto, native, generic, g4, g5, or intel")
set_property(CACHE TELEGRAM_PPC_CPU_TARGET PROPERTY STRINGS auto native generic g4 g5 intel)
set(TELEGRAM_PPC_FFMPEG_ROOT "" CACHE PATH "Optional FFmpeg prefix containing include and lib directories")
set(TELEGRAM_PPC_FFMPEG_LINKAGE "shared" CACHE STRING "FFmpeg linkage: shared or static")
set_property(CACHE TELEGRAM_PPC_FFMPEG_LINKAGE PROPERTY STRINGS shared static)
set(TELEGRAM_PPC_FFMPEG_EXTRA_LIBS "" CACHE STRING "Semicolon-separated libraries required by a static FFmpeg build")
set(TELEGRAM_PPC_BUNDLE_LIBS "" CACHE STRING "Semicolon-separated dylibs to copy into Contents/Frameworks")
set(TELEGRAM_PPC_TDLIB_LIBRARY "" CACHE FILEPATH "Optional TDLib dylib override, copied as libtdjson.dylib")
set(TELEGRAM_PPC_INSTALL_NAME_TOOL "" CACHE FILEPATH "Optional install_name_tool path for bundle load-command fixups")
set(TELEGRAM_PPC_VERSION "0.2.1" CACHE STRING "CFBundleShortVersionString value")
set(TELEGRAM_PPC_BUILD_NUMBER "0" CACHE STRING "CFBundleVersion value")

project(Sailplane LANGUAGES CXX OBJCXX)

set(TELEGRAM_PPC_SEARCH_ROOTS ${TELEGRAM_PPC_DEPENDENCY_ROOTS})
if(MACPORTS_PREFIX)
  list(APPEND TELEGRAM_PPC_SEARCH_ROOTS "${MACPORTS_PREFIX}")
elseif(EXISTS "/opt/local")
  list(APPEND TELEGRAM_PPC_SEARCH_ROOTS "/opt/local")
endif()
if(TELEGRAM_PPC_SEARCH_ROOTS)
  list(REMOVE_DUPLICATES TELEGRAM_PPC_SEARCH_ROOTS)
  list(PREPEND CMAKE_PREFIX_PATH ${TELEGRAM_PPC_SEARCH_ROOTS})
endif()

set(TELEGRAM_PPC_INCLUDE_HINTS)
set(TELEGRAM_PPC_LIBRARY_HINTS)
foreach(TELEGRAM_PPC_SEARCH_ROOT IN LISTS TELEGRAM_PPC_SEARCH_ROOTS)
  list(APPEND TELEGRAM_PPC_INCLUDE_HINTS "${TELEGRAM_PPC_SEARCH_ROOT}/include")
  list(APPEND TELEGRAM_PPC_LIBRARY_HINTS
    "${TELEGRAM_PPC_SEARCH_ROOT}/lib"
    "${TELEGRAM_PPC_SEARCH_ROOT}/libexec/tdlib/lib"
  )
endforeach()

if(TELEGRAM_PPC_FFMPEG_ROOT)
  set(TELEGRAM_PPC_FFMPEG_INCLUDE_DIR "${TELEGRAM_PPC_FFMPEG_ROOT}/include")
  set(TELEGRAM_PPC_FFMPEG_LIB_DIR "${TELEGRAM_PPC_FFMPEG_ROOT}/lib")
  if(TELEGRAM_PPC_FFMPEG_LINKAGE STREQUAL "static")
    set(TELEGRAM_PPC_FFMPEG_LIBRARY_NAMES
      "${TELEGRAM_PPC_FFMPEG_LIB_DIR}/libavcodec.a"
      "${TELEGRAM_PPC_FFMPEG_LIB_DIR}/libavformat.a"
      "${TELEGRAM_PPC_FFMPEG_LIB_DIR}/libswscale.a"
      "${TELEGRAM_PPC_FFMPEG_LIB_DIR}/libavutil.a"
    )
    foreach(TELEGRAM_PPC_FFMPEG_STATIC_LIB IN LISTS TELEGRAM_PPC_FFMPEG_LIBRARY_NAMES)
      if(NOT EXISTS "${TELEGRAM_PPC_FFMPEG_STATIC_LIB}")
        message(FATAL_ERROR "Static FFmpeg library does not exist: ${TELEGRAM_PPC_FFMPEG_STATIC_LIB}")
      endif()
    endforeach()
  elseif(TELEGRAM_PPC_FFMPEG_LINKAGE STREQUAL "shared")
    set(TELEGRAM_PPC_FFMPEG_LIBRARY_NAMES)
    foreach(TELEGRAM_PPC_FFMPEG_LIB avcodec avformat swscale avutil)
      find_library(TELEGRAM_PPC_FFMPEG_${TELEGRAM_PPC_FFMPEG_LIB}_LIBRARY
        NAMES "${TELEGRAM_PPC_FFMPEG_LIB}"
        PATHS "${TELEGRAM_PPC_FFMPEG_LIB_DIR}"
        NO_DEFAULT_PATH
        REQUIRED
      )
      list(APPEND TELEGRAM_PPC_FFMPEG_LIBRARY_NAMES "${TELEGRAM_PPC_FFMPEG_${TELEGRAM_PPC_FFMPEG_LIB}_LIBRARY}")
    endforeach()
  else()
    message(FATAL_ERROR "Unknown TELEGRAM_PPC_FFMPEG_LINKAGE: ${TELEGRAM_PPC_FFMPEG_LINKAGE}")
  endif()
  add_library(SailplaneFFmpeg INTERFACE IMPORTED)
  target_include_directories(SailplaneFFmpeg INTERFACE "${TELEGRAM_PPC_FFMPEG_INCLUDE_DIR}")
  target_link_libraries(SailplaneFFmpeg INTERFACE
    ${TELEGRAM_PPC_FFMPEG_LIBRARY_NAMES}
    ${TELEGRAM_PPC_FFMPEG_EXTRA_LIBS}
  )
  set(TELEGRAM_PPC_FFMPEG_TARGET SailplaneFFmpeg)
else()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(FFMPEG REQUIRED IMPORTED_TARGET
    libavcodec
    libavformat
    libswscale
    libavutil
  )
  set(TELEGRAM_PPC_FFMPEG_TARGET PkgConfig::FFMPEG)
endif()

find_path(NLOHMANN_JSON_INCLUDE_DIR
  NAMES nlohmann/json.hpp
  HINTS ${TELEGRAM_PPC_INCLUDE_HINTS}
  REQUIRED
)

find_library(TDJSON_LIBRARY
  NAMES tdjson
  HINTS ${TELEGRAM_PPC_LIBRARY_HINTS}
)

if(TELEGRAM_PPC_TDLIB_LIBRARY)
  if(NOT EXISTS "${TELEGRAM_PPC_TDLIB_LIBRARY}")
    message(FATAL_ERROR "TELEGRAM_PPC_TDLIB_LIBRARY does not exist: ${TELEGRAM_PPC_TDLIB_LIBRARY}")
  endif()
  set(TDJSON_LIBRARY "${TELEGRAM_PPC_TDLIB_LIBRARY}")
endif()

if(NOT TDJSON_LIBRARY)
  message(FATAL_ERROR
    "TDLib was not found. Install tdlib for this architecture, set CMAKE_PREFIX_PATH, "
    "set TELEGRAM_PPC_DEPENDENCY_ROOTS, or pass -DTELEGRAM_PPC_TDLIB_LIBRARY=/path/to/libtdjson.dylib."
  )
endif()

find_library(PPCVOIP_LIBRARY
  NAMES ppcvoip
  HINTS ${TELEGRAM_PPC_LIBRARY_HINTS}
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
  Sources/OSCompat.mm
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
  Sources/OSCompat.h
  Sources/VideoPlayerView.h
)

set(TELEGRAM_PPC_RESOURCES
  Resources/Sailplane.icns
  Resources/Sailplane.png
  Resources/Sailplane.svg
  Resources/phone_24.png
  Resources/refresh_24.png
)

add_executable(Sailplane MACOSX_BUNDLE
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

set_target_properties(Sailplane PROPERTIES
  OUTPUT_NAME Sailplane
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${TELEGRAM_PPC_VERSION}"
  MACOSX_BUNDLE_BUNDLE_VERSION "${TELEGRAM_PPC_BUILD_NUMBER}"
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED YES
  CXX_EXTENSIONS YES
  OBJCXX_STANDARD 20
  OBJCXX_STANDARD_REQUIRED YES
  OBJCXX_EXTENSIONS YES
)

target_include_directories(Sailplane PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${NLOHMANN_JSON_INCLUDE_DIR}"
)

target_compile_options(Sailplane PRIVATE
  -fpermissive
  -fno-strict-aliasing
  -fobjc-call-cxx-cdtors
  -fobjc-exceptions
  -Wall
  -Wextra
)

set(TELEGRAM_PPC_RESOLVED_CPU_TARGET "${TELEGRAM_PPC_CPU_TARGET}")
if(TELEGRAM_PPC_CPU_TARGET STREQUAL "auto")
  set(TELEGRAM_PPC_HAS_PPC_ARCH NO)
  set(TELEGRAM_PPC_HAS_INTEL_ARCH NO)
  foreach(TELEGRAM_PPC_ARCH IN LISTS CMAKE_OSX_ARCHITECTURES)
    if(TELEGRAM_PPC_ARCH MATCHES "^ppc")
      set(TELEGRAM_PPC_HAS_PPC_ARCH YES)
    elseif(TELEGRAM_PPC_ARCH STREQUAL "i386" OR TELEGRAM_PPC_ARCH STREQUAL "x86_64")
      set(TELEGRAM_PPC_HAS_INTEL_ARCH YES)
    endif()
  endforeach()

  if(TELEGRAM_PPC_HAS_PPC_ARCH AND TELEGRAM_PPC_HAS_INTEL_ARCH)
    message(FATAL_ERROR
      "Multi-architecture PPC+Intel CMake builds are not supported by this build. "
      "Configure and build thin slices separately, then combine them with lipo."
    )
  elseif(TELEGRAM_PPC_HAS_INTEL_ARCH)
    set(TELEGRAM_PPC_RESOLVED_CPU_TARGET "intel")
  elseif(TELEGRAM_PPC_HAS_PPC_ARCH)
    set(TELEGRAM_PPC_RESOLVED_CPU_TARGET "generic")
  else()
    set(TELEGRAM_PPC_RESOLVED_CPU_TARGET "native")
  endif()
endif()

message(STATUS "Sailplane CPU target: ${TELEGRAM_PPC_RESOLVED_CPU_TARGET}")

if(TELEGRAM_PPC_RESOLVED_CPU_TARGET STREQUAL "generic")
  target_compile_options(Sailplane PRIVATE
    -mno-powerpc64
    -force_cpusubtype_ALL
    -mcpu=powerpc
    -mtune=powerpc
    -mno-altivec
    -mabi=no-altivec
  )
  target_link_options(Sailplane PRIVATE
    -force_cpusubtype_ALL
    -Wl,-force_cpusubtype_ALL
  )
elseif(TELEGRAM_PPC_RESOLVED_CPU_TARGET STREQUAL "g4")
  target_compile_options(Sailplane PRIVATE -mno-powerpc64 -mcpu=7400 -mtune=7400)
elseif(TELEGRAM_PPC_RESOLVED_CPU_TARGET STREQUAL "g5")
  target_compile_options(Sailplane PRIVATE -mno-powerpc64 -mcpu=970 -mtune=970)
elseif(TELEGRAM_PPC_RESOLVED_CPU_TARGET STREQUAL "intel")
  # Intel slices do not use PowerPC-specific compiler flags.
elseif(TELEGRAM_PPC_RESOLVED_CPU_TARGET STREQUAL "native")
  # Use the compiler's default architecture and CPU flags.
else()
  message(FATAL_ERROR "Unknown TELEGRAM_PPC_CPU_TARGET: ${TELEGRAM_PPC_CPU_TARGET}")
endif()

target_compile_definitions(Sailplane PRIVATE
  TELEGRAM_PPC_SYSTEM_VERSION="${TELEGRAM_PPC_MIN_SYSTEM_VERSION}"
)

target_link_libraries(Sailplane PRIVATE
  "${COCOA_FRAMEWORK}"
  "${OPENGL_FRAMEWORK}"
  dl
  "${TELEGRAM_PPC_FFMPEG_TARGET}"
)

add_custom_command(TARGET Sailplane POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E make_directory "$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks"
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${TDJSON_LIBRARY}" "$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks/libtdjson.dylib"
  VERBATIM
)

set(TELEGRAM_PPC_BUNDLED_LIB_NAMES libtdjson.dylib)
set(TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATHS "${TDJSON_LIBRARY}")

foreach(TELEGRAM_PPC_BUNDLE_LIB IN LISTS TELEGRAM_PPC_BUNDLE_LIBS)
  if(NOT EXISTS "${TELEGRAM_PPC_BUNDLE_LIB}")
    message(FATAL_ERROR "Bundled library does not exist: ${TELEGRAM_PPC_BUNDLE_LIB}")
  endif()
  get_filename_component(TELEGRAM_PPC_BUNDLE_LIB_NAME "${TELEGRAM_PPC_BUNDLE_LIB}" NAME)
  list(APPEND TELEGRAM_PPC_BUNDLED_LIB_NAMES "${TELEGRAM_PPC_BUNDLE_LIB_NAME}")
  list(APPEND TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATHS "${TELEGRAM_PPC_BUNDLE_LIB}")
  add_custom_command(TARGET Sailplane POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${TELEGRAM_PPC_BUNDLE_LIB}" "$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks/${TELEGRAM_PPC_BUNDLE_LIB_NAME}"
    VERBATIM
  )
endforeach()

if(PPCVOIP_LIBRARY)
  list(APPEND TELEGRAM_PPC_BUNDLED_LIB_NAMES libppcvoip.dylib)
  list(APPEND TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATHS "${PPCVOIP_LIBRARY}")
  add_custom_command(TARGET Sailplane POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${PPCVOIP_LIBRARY}" "$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks/libppcvoip.dylib"
    VERBATIM
  )
endif()

if(NOT TELEGRAM_PPC_INSTALL_NAME_TOOL)
  find_program(TELEGRAM_PPC_INSTALL_NAME_TOOL_DETECTED install_name_tool)
  if(TELEGRAM_PPC_INSTALL_NAME_TOOL_DETECTED)
    set(TELEGRAM_PPC_INSTALL_NAME_TOOL "${TELEGRAM_PPC_INSTALL_NAME_TOOL_DETECTED}")
  endif()
endif()

if(TELEGRAM_PPC_INSTALL_NAME_TOOL)
  list(LENGTH TELEGRAM_PPC_BUNDLED_LIB_NAMES TELEGRAM_PPC_BUNDLED_LIB_COUNT)
  math(EXPR TELEGRAM_PPC_BUNDLED_LIB_LAST "${TELEGRAM_PPC_BUNDLED_LIB_COUNT} - 1")

  foreach(TELEGRAM_PPC_BUNDLED_LIB_INDEX RANGE 0 ${TELEGRAM_PPC_BUNDLED_LIB_LAST})
    list(GET TELEGRAM_PPC_BUNDLED_LIB_NAMES ${TELEGRAM_PPC_BUNDLED_LIB_INDEX} TELEGRAM_PPC_BUNDLED_LIB_NAME)
    add_custom_command(TARGET Sailplane POST_BUILD
      COMMAND /bin/sh -c "\"${TELEGRAM_PPC_INSTALL_NAME_TOOL}\" -id \"@executable_path/../Frameworks/${TELEGRAM_PPC_BUNDLED_LIB_NAME}\" \"$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks/${TELEGRAM_PPC_BUNDLED_LIB_NAME}\" 2>/dev/null || true"
      VERBATIM
    )
  endforeach()

  foreach(TELEGRAM_PPC_BUNDLED_LIB_INDEX RANGE 0 ${TELEGRAM_PPC_BUNDLED_LIB_LAST})
    list(GET TELEGRAM_PPC_BUNDLED_LIB_NAMES ${TELEGRAM_PPC_BUNDLED_LIB_INDEX} TELEGRAM_PPC_BUNDLED_LIB_NAME)
    list(GET TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATHS ${TELEGRAM_PPC_BUNDLED_LIB_INDEX} TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATH)
    get_filename_component(TELEGRAM_PPC_BUNDLED_LIB_REAL_PATH "${TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATH}" REALPATH)
    set(TELEGRAM_PPC_BUNDLED_LIB_LOAD_PATHS "${TELEGRAM_PPC_BUNDLED_LIB_ORIGINAL_PATH}" "${TELEGRAM_PPC_BUNDLED_LIB_REAL_PATH}")

    foreach(TELEGRAM_PPC_BUNDLED_LIB_LOAD_PATH IN LISTS TELEGRAM_PPC_BUNDLED_LIB_LOAD_PATHS)
      add_custom_command(TARGET Sailplane POST_BUILD
        COMMAND /bin/sh -c "\"${TELEGRAM_PPC_INSTALL_NAME_TOOL}\" -change \"${TELEGRAM_PPC_BUNDLED_LIB_LOAD_PATH}\" \"@executable_path/../Frameworks/${TELEGRAM_PPC_BUNDLED_LIB_NAME}\" \"$<TARGET_FILE:Sailplane>\" 2>/dev/null || true"
        VERBATIM
      )
      foreach(TELEGRAM_PPC_BUNDLED_PATCH_NAME IN LISTS TELEGRAM_PPC_BUNDLED_LIB_NAMES)
        add_custom_command(TARGET Sailplane POST_BUILD
          COMMAND /bin/sh -c "\"${TELEGRAM_PPC_INSTALL_NAME_TOOL}\" -change \"${TELEGRAM_PPC_BUNDLED_LIB_LOAD_PATH}\" \"@executable_path/../Frameworks/${TELEGRAM_PPC_BUNDLED_LIB_NAME}\" \"$<TARGET_BUNDLE_CONTENT_DIR:Sailplane>/Frameworks/${TELEGRAM_PPC_BUNDLED_PATCH_NAME}\" 2>/dev/null || true"
          VERBATIM
        )
      endforeach()
    endforeach()
  endforeach()
else()
  message(WARNING "install_name_tool was not found; copied bundle libraries may keep build-machine load commands")
endif()
