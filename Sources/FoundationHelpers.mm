#import "FoundationHelpers.h"

NSString *NSStringFromStdString(const std::string &value) {
  return [[[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding] autorelease];
}

std::string StdStringFromNSString(NSString *value) {
  if (value == nil) return std::string();
  const char *utf8 = [value UTF8String];
  return utf8 != NULL ? std::string(utf8) : std::string();
}

NSString *JSONStringFromJSON(const json &obj) {
  return NSStringFromStdString(obj.dump());
}

long long JSONLongLong(const json &value) {
  if (value.is_number_integer()) return value.get<long long>();
  if (value.is_number_unsigned()) return static_cast<long long>(value.get<unsigned long long>());
  if (value.is_number_float()) return static_cast<long long>(value.get<double>());
  if (value.is_string()) {
    std::string s = value.get<std::string>();
    return s.empty() ? 0 : strtoll(s.c_str(), NULL, 10);
  }
  return 0;
}

long long JSONLongLongAt(const json &obj, const char *key) {
  if (!obj.is_object() || !obj.contains(key)) return 0;
  return JSONLongLong(obj[key]);
}

id NSObjectFromJSON(const json &value) {
  if (value.is_null()) return [NSNull null];
  if (value.is_boolean()) return [NSNumber numberWithBool:value.get<bool>()];
  if (value.is_number_integer()) return [NSNumber numberWithLongLong:value.get<long long>()];
  if (value.is_number_unsigned()) return [NSNumber numberWithUnsignedLongLong:value.get<unsigned long long>()];
  if (value.is_number_float()) return [NSNumber numberWithDouble:value.get<double>()];
  if (value.is_string()) return NSStringFromStdString(value.get<std::string>());
  if (value.is_array()) {
    NSMutableArray *array = [NSMutableArray array];
    for (json::const_iterator it = value.begin(); it != value.end(); ++it) {
      id child = NSObjectFromJSON(*it);
      [array addObject:(child != nil ? child : [NSNull null])];
    }
    return array;
  }
  if (value.is_object()) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (json::const_iterator it = value.begin(); it != value.end(); ++it) {
      NSString *key = NSStringFromStdString(it.key());
      id child = NSObjectFromJSON(it.value());
      if (key != nil && child != nil) [dict setObject:child forKey:key];
    }
    return dict;
  }
  return nil;
}

json JSONFromCString(const char *cstr) {
  if (cstr == NULL) return json();
  json parsed = json::parse(cstr, NULL, false);
  return parsed.is_discarded() ? json() : parsed;
}

NSString *StringOrEmpty(id value) {
  return [value isKindOfClass:[NSString class]] ? value : @"";
}

NSString *TextFieldStringOrEmpty(id value) {
  if ([value isKindOfClass:[NSString class]]) return value;
  if ([value isKindOfClass:[NSDictionary class]]) return StringOrEmpty([value objectForKey:@"text"]);
  return @"";
}

long long LongLongValue(id value) {
  if ([value respondsToSelector:@selector(longLongValue)]) return [value longLongValue];
  return 0;
}

NSString *NormalizedURLString(NSString *url) {
  if (![url isKindOfClass:[NSString class]] || [url length] == 0) return nil;
  NSString *trimmed = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (![trimmed length]) return nil;
  NSString *lower = [trimmed lowercaseString];
  if ([lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"]) return trimmed;
  if ([lower hasPrefix:@"www."]) return [@"http://" stringByAppendingString:trimmed];
  return trimmed;
}
