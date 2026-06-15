#pragma once

#import "Common.h"

@interface ChatCell : NSCell {
  NSString *chatTitle_;
  NSString *chatPreview_;
  int unreadCount_;
  NSString *chatAvatarPath_;
  NSString *chatInitial_;
}
- (void)configureWithTitle:(NSString *)title preview:(NSString *)preview unread:(int)unread avatarPath:(NSString *)avatarPath initial:(NSString *)initial;
@end
