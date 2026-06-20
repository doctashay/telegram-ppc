#pragma once

#ifndef __cplusplus
#include <stddef.h>
#else
#include <cstddef>
extern "C" void _Exit(int) __attribute__((noreturn));
#endif

#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>

#ifndef CGFLOAT_DEFINED
typedef float CGFloat;
#define CGFLOAT_DEFINED 1
#endif

#ifndef NSINTEGER_DEFINED
typedef int NSInteger;
typedef unsigned int NSUInteger;
#define NSINTEGER_DEFINED 1
#endif

#include <dlfcn.h>
#include <nlohmann/json.hpp>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

#include <algorithm>
#include <ctime>
#include <map>
#include <cstdio>
#include <sstream>
#include <string>
#include <vector>

#import "TelegramCredentials.h"

using nlohmann::json;

extern const int kTDLibApiId;
extern NSString *const kTDLibApiHash;

typedef const char *(*td_receive_fn)(double timeout);
typedef void (*td_send_fn)(int client_id, const char *request);
typedef const char *(*td_execute_fn)(const char *request);
typedef int (*td_create_client_id_fn)();
