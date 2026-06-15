#import "ChatCell.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"

@implementation ChatCell

- (id)init {
  self = [super init];
  if (self) { chatTitle_ = @""; chatPreview_ = @""; unreadCount_ = 0; chatAvatarPath_ = nil; chatInitial_ = @""; }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  ChatCell *c = [super copyWithZone:zone];
  c->chatTitle_ = [chatTitle_ copy]; c->chatPreview_ = [chatPreview_ copy];
  c->unreadCount_ = unreadCount_;
  c->chatAvatarPath_ = [chatAvatarPath_ copy]; c->chatInitial_ = [chatInitial_ copy];
  return c;
}

- (void)dealloc {
  [chatTitle_ release]; [chatPreview_ release]; [chatAvatarPath_ release]; [chatInitial_ release];
  [super dealloc];
}

- (void)configureWithTitle:(NSString *)title preview:(NSString *)preview unread:(int)unread avatarPath:(NSString *)avatarPath initial:(NSString *)initial {
  if (chatTitle_) [chatTitle_ release];
  chatTitle_ = [(title ? title : @"") copy];
  if (chatPreview_) [chatPreview_ release];
  chatPreview_ = [(preview ? preview : @"") copy];
  unreadCount_ = unread;
  if (chatAvatarPath_) { [chatAvatarPath_ release]; chatAvatarPath_ = nil; }
  if ([avatarPath isKindOfClass:[NSString class]] && [avatarPath length] > 0) chatAvatarPath_ = [avatarPath copy];
  if (chatInitial_) [chatInitial_ release];
  chatInitial_ = [StringOrEmpty(initial) copy];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  (void)controlView;
  BOOL selected = [self isHighlighted];
  CGFloat avatarSize = 32.0;
  CGFloat avX = cellFrame.origin.x + 6.0;
  CGFloat avY = cellFrame.origin.y + (cellFrame.size.height - avatarSize) / 2.0;

  // Draw avatar
  if ([chatInitial_ length] > 0) {
    NSRect avr = NSMakeRect(avX, avY, avatarSize, avatarSize);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:avr];
    [NSGraphicsContext saveGraphicsState];
    [circle addClip];
    NSImage *avImg = CachedImageAtPath(chatAvatarPath_);
    if (avImg) {
      NSAffineTransform *flip = [NSAffineTransform transform];
      [flip translateXBy:NSMinX(avr) yBy:NSMaxY(avr)];
      [flip scaleXBy:1.0 yBy:-1.0];
      [flip concat];
      [avImg drawInRect:NSMakeRect(0, 0, avatarSize, avatarSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    } else {
      NSUInteger hash = [chatTitle_ hash];
      CGFloat hue = (CGFloat)(hash % 360) / 360.0;
      [[NSColor colorWithCalibratedHue:hue saturation:0.5 brightness:0.75 alpha:1.0] setFill];
      [[NSBezierPath bezierPathWithOvalInRect:avr] fill];
      NSDictionary *initAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
          [NSFont boldSystemFontOfSize:13], NSFontAttributeName,
          [NSColor whiteColor], NSForegroundColorAttributeName, nil];
      NSSize isz = [chatInitial_ sizeWithAttributes:initAttrs];
      [chatInitial_ drawAtPoint:NSMakePoint(avX + (avatarSize - isz.width) / 2.0, avY + (avatarSize - isz.height) / 2.0) withAttributes:initAttrs];
    }
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:(selected ? 1.0 : 0.72) alpha:(selected ? 0.65 : 1.0)] setStroke];
    [circle setLineWidth:1.0];
    [circle stroke];
  }

  // Text area starts after avatar
  CGFloat textStartX = avX + avatarSize + 8.0;
  CGFloat textAreaW = cellFrame.size.width - (textStartX - cellFrame.origin.x) - 8.0;
  CGFloat x = textStartX;
  CGFloat y = cellFrame.origin.y + 4.0;

  // Reserve space for badge
  CGFloat badgeW = 0;
  if (unreadCount_ > 0) badgeW = 36.0;
  CGFloat textW = textAreaW - badgeW;
  if (textW < 40.0) textW = 40.0;

  // Title - bold if unread
  NSString *title = chatTitle_;
  if (![title length]) title = @"Deleted Account";
  BOOL unread = (unreadCount_ > 0);
  NSFont *titleFont = unread ? [NSFont boldSystemFontOfSize:12] : [NSFont systemFontOfSize:12];
  NSColor *titleColor = selected ? [NSColor whiteColor] : [NSColor blackColor];
  NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:titleFont, NSFontAttributeName, titleColor, NSForegroundColorAttributeName, nil];
  NSString *drawTitle = TruncatedStringForWidth(title, titleAttrs, textW);
  DrawSingleLineEmojiText(drawTitle, NSMakeRect(x, y + 2.0, textW, 17.0), titleColor, titleFont);

  // Preview
  NSString *preview = chatPreview_;
  if ([preview length]) {
    NSColor *prevColor = selected ? [NSColor colorWithCalibratedWhite:0.85 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
    NSDictionary *prevAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:10], NSFontAttributeName, prevColor, NSForegroundColorAttributeName, nil];
    NSString *drawPrev = TruncatedStringForWidth(preview, prevAttrs, textW);
    DrawSingleLineEmojiText(drawPrev, NSMakeRect(x, y + 21.0, textW, 14.0), prevColor, [NSFont systemFontOfSize:10]);
  }

  // Unread badge
  if (unreadCount_ > 0) {
    NSString *countStr = unreadCount_ > 99 ? @"99+" : [NSString stringWithFormat:@"%d", unreadCount_];
    NSColor *badgeTextColor = selected ? [NSColor colorWithCalibratedRed:0.18 green:0.45 blue:0.82 alpha:1.0] : [NSColor whiteColor];
    NSDictionary *badgeAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:10], NSFontAttributeName, badgeTextColor, NSForegroundColorAttributeName, nil];
    NSSize sz = [countStr sizeWithAttributes:badgeAttrs];
    CGFloat bw = sz.width + 10.0; if (bw < 22.0) bw = 22.0;
    CGFloat bh = 18.0;
    CGFloat bx = cellFrame.origin.x + cellFrame.size.width - bw - 12.0;
    CGFloat by = cellFrame.origin.y + (cellFrame.size.height - bh) / 2.0;
    NSRect badgeRect = NSMakeRect(bx, by, bw, bh);
    NSColor *badgeFill = selected ? [NSColor whiteColor] : [NSColor colorWithCalibratedRed:0.35 green:0.70 blue:0.92 alpha:1.0];
    [badgeFill setFill];
    [[NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:9.0 yRadius:9.0] fill];
    [countStr drawAtPoint:NSMakePoint(bx + (bw - sz.width) / 2.0, by + (bh - sz.height) / 2.0) withAttributes:badgeAttrs];
  }

  NSColor *sep = selected ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.18] : [NSColor colorWithCalibratedWhite:0.84 alpha:1.0];
  [sep setStroke];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(cellFrame.origin.x + 46.0, cellFrame.origin.y + cellFrame.size.height - 0.5)
                            toPoint:NSMakePoint(cellFrame.origin.x + cellFrame.size.width, cellFrame.origin.y + cellFrame.size.height - 0.5)];
}

@end
