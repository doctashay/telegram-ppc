#pragma once

#import "Common.h"

NSString *NSStringFromStdString(const std::string &value);
std::string StdStringFromNSString(NSString *value);
NSString *JSONStringFromJSON(const json &obj);
long long JSONLongLong(const json &value);
long long JSONLongLongAt(const json &obj, const char *key);
id NSObjectFromJSON(const json &value);
json JSONFromCString(const char *cstr);
NSString *StringOrEmpty(id value);
NSString *TextFieldStringOrEmpty(id value);
long long LongLongValue(id value);
NSString *NormalizedURLString(NSString *url);
