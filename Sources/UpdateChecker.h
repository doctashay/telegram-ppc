#pragma once

#import <Cocoa/Cocoa.h>

@interface UpdateChecker : NSObject
+ (void)scheduleAutomaticCheck;
+ (void)checkNow;
@end
