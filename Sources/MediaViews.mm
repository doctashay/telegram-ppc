#import "MediaViews.h"
#import "ImageDrawing.h"

@implementation MediaFrameView
- (id)initWithFrame:(NSRect)frame thumbnailPath:(NSString *)thumbnailPath controlsHeight:(CGFloat)controlsHeight {
  self = [super initWithFrame:frame];
  if (self) {
    thumbnailPath_ = [thumbnailPath copy];
    controlsHeight_ = controlsHeight;
  }
  return self;
}

- (void)dealloc {
  [thumbnailPath_ release];
  [super dealloc];
}

- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  NSRect b = [self bounds];
  NSRect mediaRect = NSMakeRect(1.0, controlsHeight_, b.size.width - 2.0, b.size.height - controlsHeight_ - 1.0);
  if (mediaRect.size.width < 1.0) mediaRect.size.width = b.size.width;
  if (mediaRect.size.height < 1.0) mediaRect.size.height = b.size.height - controlsHeight_;
  NSRect r = NSInsetRect(b, 0.5, 0.5);
  NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:5.0 yRadius:5.0];
  [[NSColor colorWithCalibratedWhite:0.96 alpha:1.0] setFill];
  [p fill];
  NSImage *thumb = ScaledCachedImageAtPath(thumbnailPath_, mediaRect.size.width, mediaRect.size.height, NO);
  if (thumb) {
    DrawRoundedImage(thumb, mediaRect, 4.0, [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
  } else {
    [[NSColor colorWithCalibratedWhite:0.12 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:mediaRect xRadius:4.0 yRadius:4.0] fill];
  }
  [[NSColor colorWithCalibratedWhite:0.62 alpha:1.0] setStroke];
  [p setLineWidth:1.0];
  [p stroke];
}
@end

@implementation FrameBarView
- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  NSRect b = [self bounds];
  NSGradient *g = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.86 alpha:1.0]
                                                 endingColor:[NSColor colorWithCalibratedWhite:0.72 alpha:1.0]] autorelease];
  [g drawInRect:b angle:90.0];
  [[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] setStroke];
  [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(b), NSMaxY(b) - 0.5)
                            toPoint:NSMakePoint(NSMaxX(b), NSMaxY(b) - 0.5)];
}
@end

NSImage *ToolbarIconImage(NSString *name, CGFloat size) {
  NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
  NSImage *img = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
  if (img) [img setSize:NSMakeSize(size, size)];
  return img;
}

@implementation PlaybackButtonView
- (BOOL)isOpaque { return NO; }

- (void)setPaused:(BOOL)paused {
  paused_ = paused;
  [self setToolTip:(paused_ ? @"Play" : @"Pause")];
  [self setNeedsDisplay:YES];
}

- (BOOL)isPaused { return paused_; }

- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  NSRect b = [self bounds];
  NSRect r = NSInsetRect(b, 0.5, 0.5);
  NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:r xRadius:4.0 yRadius:4.0];
  NSColor *top = pressed_ ? [NSColor colorWithCalibratedWhite:0.70 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
  NSColor *bottom = pressed_ ? [NSColor colorWithCalibratedWhite:0.86 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.78 alpha:1.0];
  NSGradient *g = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
  [NSGraphicsContext saveGraphicsState];
  [bg addClip];
  [g drawInRect:b angle:90.0];
  [NSGraphicsContext restoreGraphicsState];
  [[NSColor colorWithCalibratedWhite:0.48 alpha:1.0] setStroke];
  [bg setLineWidth:1.0];
  [bg stroke];

  [[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] setFill];
  CGFloat w = b.size.width, h = b.size.height;
  if (paused_) {
    NSBezierPath *tri = [NSBezierPath bezierPath];
    [tri moveToPoint:NSMakePoint(w * 0.38, h * 0.26)];
    [tri lineToPoint:NSMakePoint(w * 0.38, h * 0.74)];
    [tri lineToPoint:NSMakePoint(w * 0.72, h * 0.50)];
    [tri closePath];
    [tri fill];
  } else {
    NSRect left = NSMakeRect(w * 0.34, h * 0.28, w * 0.10, h * 0.44);
    NSRect right = NSMakeRect(w * 0.56, h * 0.28, w * 0.10, h * 0.44);
    [[NSBezierPath bezierPathWithRoundedRect:left xRadius:1.0 yRadius:1.0] fill];
    [[NSBezierPath bezierPathWithRoundedRect:right xRadius:1.0 yRadius:1.0] fill];
  }
}

- (void)mouseDown:(NSEvent *)event {
  (void)event;
  pressed_ = YES;
  [self setNeedsDisplay:YES];
  BOOL inside = YES;
  while (YES) {
    NSEvent *e = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    if ([e type] == NSLeftMouseDragged) {
      NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];
      inside = NSPointInRect(p, [self bounds]);
      [self setNeedsDisplay:YES];
    } else {
      NSPoint p = [self convertPoint:[e locationInWindow] fromView:nil];
      inside = NSPointInRect(p, [self bounds]);
      break;
    }
  }
  pressed_ = NO;
  [self setNeedsDisplay:YES];
  if (inside) [NSApp sendAction:[self action] to:[self target] from:self];
}
@end

void SetPlaybackButtonIcon(PlaybackButtonView *button, BOOL paused) {
  if (!button) return;
  [button setPaused:paused];
}

@implementation ImagePreviewOverlayView
- (id)initWithFrame:(NSRect)frame image:(NSImage *)image {
  self = [super initWithFrame:frame];
  if (self) {
    image_ = [image retain];
    [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  }
  return self;
}

- (void)dealloc {
  [image_ release];
  [super dealloc];
}

- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
  (void)dirtyRect;
  NSRect b = [self bounds];
  [[NSColor colorWithCalibratedWhite:0.0 alpha:0.68] setFill];
  NSRectFillUsingOperation(b, NSCompositeSourceOver);
  if (!image_) return;
  NSSize src = ImagePixelSize(image_);
  if (src.width <= 0.0 || src.height <= 0.0) return;
  NSRect fit = NSInsetRect(b, 28.0, 28.0);
  CGFloat s = fit.size.width / src.width;
  if (src.height * s > fit.size.height) s = fit.size.height / src.height;
  if (s > 1.0) s = 1.0;
  CGFloat w = floor(src.width * s);
  CGFloat h = floor(src.height * s);
  NSRect imgRect = NSMakeRect(floor(NSMidX(b) - w / 2.0), floor(NSMidY(b) - h / 2.0), w, h);
  NSRect shadowRect = NSInsetRect(imgRect, -6.0, -6.0);
  NSBezierPath *shadowPath = [NSBezierPath bezierPathWithRoundedRect:shadowRect xRadius:8.0 yRadius:8.0];
  [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setFill];
  [shadowPath fill];
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  DrawImageInRectUpright(image_, imgRect);
  [NSGraphicsContext restoreGraphicsState];
  StrokeRoundedBorder(imgRect, 5.0, [NSColor colorWithCalibratedWhite:1.0 alpha:0.55]);
}

- (void)mouseDown:(NSEvent *)event {
  (void)event;
  [self removeFromSuperview];
}
@end
