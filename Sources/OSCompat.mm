#import "OSCompat.h"

BOOL EnsureDirectoryExists(NSString *path) {
  if (![path length]) return NO;

  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  if ([fm fileExistsAtPath:path isDirectory:&isDirectory]) return isDirectory;

  NSString *parent = [path stringByDeletingLastPathComponent];
  if ([parent length] && ![parent isEqualToString:path] && !EnsureDirectoryExists(parent)) return NO;

  return [fm createDirectoryAtPath:path attributes:nil];
}

BOOL MovePathReplacingDestination(NSString *sourcePath, NSString *destinationPath) {
  if (![sourcePath length] || ![destinationPath length]) return NO;

  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm respondsToSelector:@selector(moveItemAtPath:toPath:error:)]) {
    return [fm moveItemAtPath:sourcePath toPath:destinationPath error:nil];
  }

  return [fm movePath:sourcePath toPath:destinationPath handler:nil];
}
