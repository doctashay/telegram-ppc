#pragma once

#import "Common.h"

BOOL EnsureDirectoryExists(NSString *path);
BOOL MovePathReplacingDestination(NSString *sourcePath, NSString *destinationPath);
