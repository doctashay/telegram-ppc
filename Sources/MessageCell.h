#pragma once

#import "Common.h"

@interface MessageCell : NSCell
- (void)configureWithMessageDict:(NSDictionary *)dict;
+ (CGFloat)cellHeightForMessageDict:(NSDictionary *)dict maxWidth:(CGFloat)maxWidth;
@end

BOOL MessageBodyTextRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut, NSString **displayTextOut);
BOOL MessageMediaRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut);
BOOL MessageWebPreviewRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut);
