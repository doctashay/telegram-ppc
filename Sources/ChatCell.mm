#import "ChatCell.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"

@implementation ChatCell

static NSMutableDictionary *ChatCellStateTable(void) {
  static NSMutableDictionary *states = nil;
  if (!states) states = [[NSMutableDictionary alloc] init];
  return states;
}

static NSValue *ChatCellStateKey(ChatCell *cell) {
  return [NSValue valueWithPointer:cell];
}

static NSMutableDictionary *ChatCellState(ChatCell *cell) {
  NSMutableDictionary *states = ChatCellStateTable();
  NSValue *key = ChatCellStateKey(cell);
  NSMutableDictionary *state = [states objectForKey:key];
  if (!state) {
    state = [NSMutableDictionary dictionary];
    [state setObject:@"" forKey:@"title"];
    [state setObject:@"" forKey:@"preview"];
    [state setObject:[NSNumber numberWithInt:0] forKey:@"unread"];
    [state setObject:@"" forKey:@"initial"];
    [states setObject:state forKey:key];
  }
  return state;
}

- (id)init {
  self = [super init];
  if (self) ChatCellState(self);
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  ChatCell *c = [super copyWithZone:zone];
  NSMutableDictionary *state = ChatCellState(self);
  NSMutableDictionary *copyState = [NSMutableDictionary dictionaryWithDictionary:state];
  [ChatCellStateTable() setObject:copyState forKey:ChatCellStateKey(c)];
  return c;
}

- (void)dealloc {
  [ChatCellStateTable() removeObjectForKey:ChatCellStateKey(self)];
  [super dealloc];
}

- (void)configureWithTitle:(NSString *)title preview:(NSString *)preview unread:(int)unread avatarPath:(NSString *)avatarPath initial:(NSString *)initial {
  NSMutableDictionary *state = ChatCellState(self);
  [state setObject:StringOrEmpty(title) forKey:@"title"];
  [state setObject:StringOrEmpty(preview) forKey:@"preview"];
  [state setObject:[NSNumber numberWithInt:unread] forKey:@"unread"];
  if ([avatarPath isKindOfClass:[NSString class]] && [avatarPath length] > 0) [state setObject:avatarPath forKey:@"avatarPath"];
  else [state removeObjectForKey:@"avatarPath"];
  [state setObject:StringOrEmpty(initial) forKey:@"initial"];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  (void)controlView;
  NSDictionary *state = ChatCellState(self);
  NSString *chatTitle = StringOrEmpty([state objectForKey:@"title"]);
  NSString *chatPreview = StringOrEmpty([state objectForKey:@"preview"]);
  NSString *chatAvatarPath = StringOrEmpty([state objectForKey:@"avatarPath"]);
  NSString *chatInitial = StringOrEmpty([state objectForKey:@"initial"]);
  int unreadCount = [[state objectForKey:@"unread"] intValue];
  BOOL selected = [self isHighlighted];
  CGFloat avatarSize = 32.0;
  CGFloat avX = cellFrame.origin.x + 6.0;
  CGFloat avY = cellFrame.origin.y + (cellFrame.size.height - avatarSize) / 2.0;

  // Draw avatar
  if ([chatInitial length] > 0) {
    NSRect avr = NSMakeRect(avX, avY, avatarSize, avatarSize);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:avr];
    [NSGraphicsContext saveGraphicsState];
    [circle addClip];
    NSImage *avImg = CachedImageAtPath(chatAvatarPath);
    if (avImg) {
      NSAffineTransform *flip = [NSAffineTransform transform];
      [flip translateXBy:NSMinX(avr) yBy:NSMaxY(avr)];
      [flip scaleXBy:1.0 yBy:-1.0];
      [flip concat];
      [avImg drawInRect:NSMakeRect(0, 0, avatarSize, avatarSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    } else {
      NSUInteger hash = [chatTitle hash];
      CGFloat hue = (CGFloat)(hash % 360) / 360.0;
      [[NSColor colorWithCalibratedHue:hue saturation:0.5 brightness:0.75 alpha:1.0] setFill];
      [[NSBezierPath bezierPathWithOvalInRect:avr] fill];
      NSDictionary *initAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
          [NSFont boldSystemFontOfSize:13], NSFontAttributeName,
          [NSColor whiteColor], NSForegroundColorAttributeName, nil];
      NSSize isz = [chatInitial sizeWithAttributes:initAttrs];
      [chatInitial drawAtPoint:NSMakePoint(avX + (avatarSize - isz.width) / 2.0, avY + (avatarSize - isz.height) / 2.0) withAttributes:initAttrs];
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
  if (unreadCount > 0) badgeW = 36.0;
  CGFloat textW = textAreaW - badgeW;
  if (textW < 40.0) textW = 40.0;

  // Title - bold if unread
  NSString *title = chatTitle;
  if (![title length]) title = @"Deleted Account";
  BOOL unread = (unreadCount > 0);
  NSFont *titleFont = unread ? [NSFont boldSystemFontOfSize:12] : [NSFont systemFontOfSize:12];
  NSColor *titleColor = selected ? [NSColor whiteColor] : [NSColor blackColor];
  NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:titleFont, NSFontAttributeName, titleColor, NSForegroundColorAttributeName, nil];
  NSString *drawTitle = TruncatedStringForWidth(title, titleAttrs, textW);
  DrawSingleLineEmojiText(drawTitle, NSMakeRect(x, y + 2.0, textW, 17.0), titleColor, titleFont);

  // Preview
  NSString *preview = chatPreview;
  if ([preview length]) {
    NSColor *prevColor = selected ? [NSColor colorWithCalibratedWhite:0.85 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
    NSDictionary *prevAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:10], NSFontAttributeName, prevColor, NSForegroundColorAttributeName, nil];
    NSString *drawPrev = TruncatedStringForWidth(preview, prevAttrs, textW);
    DrawSingleLineEmojiText(drawPrev, NSMakeRect(x, y + 21.0, textW, 14.0), prevColor, [NSFont systemFontOfSize:10]);
  }

  // Unread badge
  if (unreadCount > 0) {
    NSString *countStr = unreadCount > 99 ? @"99+" : [NSString stringWithFormat:@"%d", unreadCount];
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
    [RoundedBezierPath(badgeRect, 9.0) fill];
    [countStr drawAtPoint:NSMakePoint(bx + (bw - sz.width) / 2.0, by + (bh - sz.height) / 2.0) withAttributes:badgeAttrs];
  }

  NSColor *sep = selected ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.18] : [NSColor colorWithCalibratedWhite:0.84 alpha:1.0];
  [sep setStroke];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(cellFrame.origin.x + 46.0, cellFrame.origin.y + cellFrame.size.height - 0.5)
                            toPoint:NSMakePoint(cellFrame.origin.x + cellFrame.size.width, cellFrame.origin.y + cellFrame.size.height - 0.5)];
}

@end
