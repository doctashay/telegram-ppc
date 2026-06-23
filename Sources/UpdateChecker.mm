#import "UpdateChecker.h"
#import "FoundationHelpers.h"

#include <curl/curl.h>

static NSString *const kSailplaneLatestReleaseURL = @"https://api.github.com/repos/doctashay/telegram-ppc/releases/latest";
static NSString *const kSailplaneReleasesURL = @"https://github.com/doctashay/telegram-ppc/releases/latest";
static NSString *const kSailplaneLastUpdateCheckKey = @"SailplaneLastUpdateCheckDate";
static NSString *const kSailplaneSkippedUpdateTagKey = @"SailplaneSkippedUpdateTag";

static size_t SailplaneCurlWrite(char *ptr, size_t size, size_t nmemb, void *userdata) {
  NSMutableData *data = (NSMutableData *)userdata;
  [data appendBytes:ptr length:(size * nmemb)];
  return size * nmemb;
}

static NSData *SailplaneFetchURL(NSURL *url) {
  CURL *curl = curl_easy_init();
  if (!curl) return nil;

  NSMutableData *data = [NSMutableData data];
  struct curl_slist *headers = NULL;
  headers = curl_slist_append(headers, "Accept: application/vnd.github+json");

  curl_easy_setopt(curl, CURLOPT_URL, [[url absoluteString] UTF8String]);
  curl_easy_setopt(curl, CURLOPT_USERAGENT, "Sailplane");
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
  curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 20L);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, SailplaneCurlWrite);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, data);

  NSString *caBundle = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
  if ([caBundle length]) curl_easy_setopt(curl, CURLOPT_CAINFO, [caBundle fileSystemRepresentation]);

  CURLcode result = curl_easy_perform(curl);
  long status = 0;
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);

  curl_slist_free_all(headers);
  curl_easy_cleanup(curl);

  if (result != CURLE_OK || status >= 400 || [data length] == 0) return nil;
  return data;
}

static NSArray *SailplaneVersionComponents(NSString *version) {
  if (![version isKindOfClass:[NSString class]]) return [NSArray array];
  NSString *trimmed = [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed hasPrefix:@"v"] || [trimmed hasPrefix:@"V"]) trimmed = [trimmed substringFromIndex:1];
  NSArray *rawParts = [trimmed componentsSeparatedByString:@"."];
  NSMutableArray *parts = [NSMutableArray array];
  for (NSUInteger i = 0; i < [rawParts count]; i++) {
    NSScanner *scanner = [NSScanner scannerWithString:[rawParts objectAtIndex:i]];
    int value = 0;
    if (![scanner scanInt:&value]) value = 0;
    [parts addObject:[NSNumber numberWithInteger:value]];
  }
  return parts;
}

static NSInteger SailplaneCompareVersions(NSString *lhs, NSString *rhs) {
  NSArray *left = SailplaneVersionComponents(lhs);
  NSArray *right = SailplaneVersionComponents(rhs);
  NSUInteger count = ([left count] > [right count]) ? [left count] : [right count];
  for (NSUInteger i = 0; i < count; i++) {
    NSInteger l = (i < [left count]) ? [[left objectAtIndex:i] integerValue] : 0;
    NSInteger r = (i < [right count]) ? [[right objectAtIndex:i] integerValue] : 0;
    if (l < r) return -1;
    if (l > r) return 1;
  }
  return 0;
}

@interface UpdateChecker (Private)
+ (void)checkInBackground:(id)sender;
+ (void)presentUpdateAvailable:(NSDictionary *)release;
+ (void)presentNoUpdateAvailable:(id)sender;
+ (void)presentUpdateCheckFailed:(id)sender;
@end

@implementation UpdateChecker

+ (void)initialize {
  if (self == [UpdateChecker class]) curl_global_init(CURL_GLOBAL_DEFAULT);
}

+ (void)scheduleAutomaticCheck {
  [NSThread detachNewThreadSelector:@selector(checkInBackground:) toTarget:self withObject:[NSNumber numberWithBool:NO]];
}

+ (void)checkNow {
  [NSThread detachNewThreadSelector:@selector(checkInBackground:) toTarget:self withObject:[NSNumber numberWithBool:YES]];
}

+ (void)checkInBackground:(id)sender {
  BOOL manual = [sender respondsToSelector:@selector(boolValue)] ? [sender boolValue] : NO;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *data = SailplaneFetchURL([NSURL URLWithString:kSailplaneLatestReleaseURL]);
  if (!data) {
    if (manual) [self performSelectorOnMainThread:@selector(presentUpdateCheckFailed:) withObject:nil waitUntilDone:YES];
    [pool release];
    return;
  }

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:[NSDate date] forKey:kSailplaneLastUpdateCheckKey];
  [defaults synchronize];

  NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
  json releaseJSON = JSONFromCString([jsonString UTF8String]);
  if (!releaseJSON.is_object()) {
    if (manual) [self performSelectorOnMainThread:@selector(presentUpdateCheckFailed:) withObject:nil waitUntilDone:YES];
    [pool release];
    return;
  }

  NSString *tag = (releaseJSON.contains("tag_name") && releaseJSON["tag_name"].is_string()) ? NSStringFromStdString(releaseJSON["tag_name"].get<std::string>()) : @"";
  NSString *htmlURL = (releaseJSON.contains("html_url") && releaseJSON["html_url"].is_string()) ? NSStringFromStdString(releaseJSON["html_url"].get<std::string>()) : kSailplaneReleasesURL;
  NSString *name = (releaseJSON.contains("name") && releaseJSON["name"].is_string()) ? NSStringFromStdString(releaseJSON["name"].get<std::string>()) : tag;
  BOOL draft = releaseJSON.contains("draft") && releaseJSON["draft"].is_boolean() ? releaseJSON["draft"].get<bool>() : false;
  BOOL prerelease = releaseJSON.contains("prerelease") && releaseJSON["prerelease"].is_boolean() ? releaseJSON["prerelease"].get<bool>() : false;
  if (![tag length] || draft || prerelease) {
    if (manual) [self performSelectorOnMainThread:@selector(presentNoUpdateAvailable:) withObject:nil waitUntilDone:YES];
    [pool release];
    return;
  }

  NSString *current = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
  NSString *skipped = [[NSUserDefaults standardUserDefaults] stringForKey:kSailplaneSkippedUpdateTagKey];
  if (SailplaneCompareVersions(current, tag) < 0 && ![skipped isEqualToString:tag]) {
    NSDictionary *release = [[NSDictionary alloc] initWithObjectsAndKeys:
      tag, @"tag",
      htmlURL, @"url",
      name, @"name",
      current ? current : @"", @"current",
      nil];
    [self performSelectorOnMainThread:@selector(presentUpdateAvailable:) withObject:release waitUntilDone:YES];
    [release release];
  } else if (manual) {
    [self performSelectorOnMainThread:@selector(presentNoUpdateAvailable:) withObject:nil waitUntilDone:YES];
  }
  [pool release];
}

+ (void)presentUpdateAvailable:(NSDictionary *)release {
  NSString *tag = StringOrEmpty([release objectForKey:@"tag"]);
  NSString *current = StringOrEmpty([release objectForKey:@"current"]);
  NSString *url = StringOrEmpty([release objectForKey:@"url"]);
  NSString *name = StringOrEmpty([release objectForKey:@"name"]);
  if (![tag length]) return;
  if (![name length]) name = tag;

  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:@"A Sailplane update is available"];
  [alert setInformativeText:[NSString stringWithFormat:@"%@ is available. You are running %@.", name, [current length] ? current : @"this version"]];
  [alert addButtonWithTitle:@"Download"];
  [alert addButtonWithTitle:@"Later"];
  [alert addButtonWithTitle:@"Skip This Version"];
  NSInteger result = [alert runModal];
  if (result == NSAlertFirstButtonReturn) {
    NSString *downloadURL = [url length] ? url : (NSString *)kSailplaneReleasesURL;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:downloadURL]];
  } else if (result == NSAlertThirdButtonReturn) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:tag forKey:kSailplaneSkippedUpdateTagKey];
    [defaults synchronize];
  }
}

+ (void)presentNoUpdateAvailable:(id)sender {
  (void)sender;
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:@"Sailplane is up to date"];
  [alert setInformativeText:@"You are running the latest available release."];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

+ (void)presentUpdateCheckFailed:(id)sender {
  (void)sender;
  NSAlert *alert = [[[NSAlert alloc] init] autorelease];
  [alert setMessageText:@"Unable to check for updates"];
  [alert setInformativeText:@"Sailplane could not contact GitHub. Check your connection and try again later."];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

@end
