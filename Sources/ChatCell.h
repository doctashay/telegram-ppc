#pragma once

#import "Common.h"

@interface ChatCell : NSCell
- (void)configureWithTitle:(NSString *)title preview:(NSString *)preview unread:(int)unread avatarPath:(NSString *)avatarPath initial:(NSString *)initial;
@end
