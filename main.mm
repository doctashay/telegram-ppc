#import "Sources/Common.h"
#import "Sources/AppDelegate.h"

int main(int argc, const char *argv[]) {
  (void)argc; (void)argv;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSApplication *app = [NSApplication sharedApplication];
  AppDelegate *del = [[[AppDelegate alloc] init] autorelease];
  [app setDelegate:del];
  [del createMenus];
  [app run];
  [pool release];
  return 0;
}
