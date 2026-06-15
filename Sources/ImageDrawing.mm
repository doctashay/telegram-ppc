#import "ImageDrawing.h"
#import "EmojiText.h"

NSImage *CachedImageAtPath(NSString *path) {
  if (![path isKindOfClass:[NSString class]] || [path length] == 0) return nil;
  static NSMutableDictionary *cache = nil;
  static NSMutableArray *order = nil;
  if (!cache) {
    cache = [[NSMutableDictionary alloc] init];
    order = [[NSMutableArray alloc] init];
  }
  NSImage *cached = [cache objectForKey:path];
  if (cached) {
    [order removeObject:path];
    [order addObject:path];
    return cached;
  }
  NSImage *img = [[NSImage alloc] initWithContentsOfFile:path];
  if (img) {
    [cache setObject:img forKey:path];
    [order addObject:path];
    [img release];
    while ([order count] > 16) {
      NSString *oldest = [[[order objectAtIndex:0] retain] autorelease];
      [cache removeObjectForKey:oldest];
      [order removeObjectAtIndex:0];
    }
  }
  return img;
}

NSImage *ScaledCachedImageAtPath(NSString *path, CGFloat width, CGFloat height, BOOL flipped) {
  if (![path isKindOfClass:[NSString class]] || [path length] == 0 || width <= 0.0 || height <= 0.0) return nil;
  static NSMutableDictionary *cache = nil;
  static NSMutableArray *order = nil;
  if (!cache) {
    cache = [[NSMutableDictionary alloc] init];
    order = [[NSMutableArray alloc] init];
  }
  int iw = (int)ceil(width), ih = (int)ceil(height);
  NSString *key = [NSString stringWithFormat:@"%@|%d|%d|%d", path, iw, ih, flipped ? 1 : 0];
  NSImage *cached = [cache objectForKey:key];
  if (cached) {
    [order removeObject:key];
    [order addObject:key];
    return cached;
  }

  NSImage *src = CachedImageAtPath(path);
  if (!src) return nil;
  NSImage *scaled = [[NSImage alloc] initWithSize:NSMakeSize(iw, ih)];
  [scaled lockFocus];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  if (flipped) {
    NSAffineTransform *flip = [NSAffineTransform transform];
    [flip translateXBy:0.0 yBy:(CGFloat)ih];
    [flip scaleXBy:1.0 yBy:-1.0];
    [flip concat];
  }
  [src drawInRect:NSMakeRect(0, 0, iw, ih) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
  [scaled unlockFocus];
  [cache setObject:scaled forKey:key];
  [order addObject:key];
  [scaled release];
  while ([order count] > 40) {
    NSString *oldest = [[[order objectAtIndex:0] retain] autorelease];
    [cache removeObjectForKey:oldest];
    [order removeObjectAtIndex:0];
  }
  return scaled;
}

void StrokeRoundedBorder(NSRect rect, CGFloat radius, NSColor *color) {
  NSRect r = NSInsetRect(rect, 0.5, 0.5);
  NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
  [p setLineWidth:1.0];
  [color setStroke];
  [p stroke];
}

NSSize ImagePixelSize(NSImage *img) {
  if (!img) return NSMakeSize(0.0, 0.0);
  NSSize best = [img size];
  CGFloat bestArea = best.width * best.height;
  NSArray *reps = [img representations];
  for (NSUInteger i = 0; i < [reps count]; i++) {
    NSImageRep *rep = [reps objectAtIndex:i];
    CGFloat w = (CGFloat)[rep pixelsWide];
    CGFloat h = (CGFloat)[rep pixelsHigh];
    CGFloat area = w * h;
    if (w > 0.0 && h > 0.0 && area > bestArea) {
      best = NSMakeSize(w, h);
      bestArea = area;
    }
  }
  return best;
}

void DrawImageInRectUpright(NSImage *img, NSRect rect) {
  if (!img || rect.size.width <= 0.0 || rect.size.height <= 0.0) return;
  NSGraphicsContext *ctx = [NSGraphicsContext currentContext];
  if ([ctx isFlipped]) {
    NSAffineTransform *flip = [NSAffineTransform transform];
    [flip translateXBy:rect.origin.x yBy:rect.origin.y + rect.size.height];
    [flip scaleXBy:1.0 yBy:-1.0];
    [flip concat];
    [img drawInRect:NSMakeRect(0.0, 0.0, rect.size.width, rect.size.height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
  } else {
    [img drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
  }
}

void DrawRoundedImage(NSImage *img, NSRect rect, CGFloat radius, NSColor *borderColor) {
  NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
  [clip addClip];
  DrawImageInRectUpright(img, rect);
  [NSGraphicsContext restoreGraphicsState];
  StrokeRoundedBorder(rect, radius, borderColor);
}
