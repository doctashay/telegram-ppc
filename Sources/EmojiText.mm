#import "EmojiText.h"
#import "FoundationHelpers.h"

static BOOL IsEmojiCodepoint(uint32_t cp) {
  // ZWJ and variation selectors are handled by segment parsing, not as standalone emoji
  if (cp == 0x200D || cp == 0xFE0F || cp == 0xFE0E) return NO;
  return (cp >= 0x1F600 && cp <= 0x1F64F) ||  // Emoticons
         (cp >= 0x1F300 && cp <= 0x1F5FF) ||  // Misc Symbols & Pictographs
         (cp >= 0x1F680 && cp <= 0x1F6FF) ||  // Transport & Map
         (cp >= 0x1F1E0 && cp <= 0x1F1FF) ||  // Flags
         (cp >= 0x2600 && cp <= 0x27BF)   ||  // Misc Symbols / Dingbats
         (cp >= 0x1F900 && cp <= 0x1F9FF) ||  // Supplemental Symbols
         (cp >= 0x1FA00 && cp <= 0x1FA6F) ||  // Chess / Extended-A
         (cp >= 0x1FA70 && cp <= 0x1FAFF) ||  // Symbols Extended-A
         (cp >= 0x1F700 && cp <= 0x1F77F) ||  // Alchemical
         (cp >= 0x1F780 && cp <= 0x1F7FF) ||  // Geometric Extended
         (cp >= 0x1F800 && cp <= 0x1F8FF) ||  // Arrows-C
         (cp >= 0x1F000 && cp <= 0x1F02F) ||  // Mahjong / Domino
         (cp >= 0x1F0A0 && cp <= 0x1F0FF) ||  // Playing Cards
         (cp >= 0x231A && cp <= 0x231B)   ||  // Watch / Hourglass
         (cp >= 0x23E9 && cp <= 0x23F3)   ||  // Double triangles
         (cp >= 0x23F8 && cp <= 0x23FA)   ||  // Control symbols
         (cp >= 0x25AA && cp <= 0x25AB)   ||  // Small squares
         (cp >= 0x25B6 && cp <= 0x25C0)   ||  // Play / Reverse
         (cp >= 0x25FB && cp <= 0x25FE)   ||  // Medium squares
         (cp >= 0x2934 && cp <= 0x2935)   ||  // Curved arrows
         (cp >= 0x2B05 && cp <= 0x2B07)   ||  // Big arrows
         (cp >= 0x2B1B && cp <= 0x2B1C)   ||  // Large squares
         (cp >= 0x2B50 && cp <= 0x2B55)   ||  // Stars
         (cp >= 0x3030 && cp <= 0x303D)   ||  // Wavy dash etc
         (cp >= 0x3297 && cp <= 0x3299)   ||  // Japanese
         (cp >= 0x2648 && cp <= 0x2653)   ||  // Zodiac
         (cp >= 0x265F && cp <= 0x2660)   ||  // Chess
         (cp >= 0x2663 && cp <= 0x2668)   ||  // Card suits
         (cp >= 0x267E && cp <= 0x267F)   ||  // Symbols
         (cp >= 0x2692 && cp <= 0x269C)   ||  // Tools
         (cp >= 0x26A0 && cp <= 0x26AB)   ||  // Warning / Circles
         (cp >= 0x26BD && cp <= 0x26BF)   ||  // Sports
         (cp >= 0x26C4 && cp <= 0x26CD)   ||  // Weather
         (cp >= 0x26CF && cp <= 0x26D4)   ||  // Transport
         (cp >= 0x26E9 && cp <= 0x26EA)   ||  // Church / Tent
         (cp >= 0x26F0 && cp <= 0x26FA)   ||  // Mountain / Tent
         (cp >= 0x26FD && cp <= 0x26FD)   ||  // Fuel pump
         (cp >= 0x2702 && cp <= 0x2708)   ||  // Scissors / Plane
         (cp >= 0x2709 && cp <= 0x270F)   ||  // Envelope / Pencil
         (cp >= 0x2712 && cp <= 0x2716)   ||  // Nib / Cross
         (cp >= 0x271D && cp <= 0x271D)   ||  // Latin cross
         (cp >= 0x2721 && cp <= 0x2721)   ||  // Star of David
         (cp >= 0x2728 && cp <= 0x2728)   ||  // Sparkles
         (cp >= 0x2733 && cp <= 0x2734)   ||  // Florals
         (cp >= 0x2744 && cp <= 0x274E)   ||  // Snowflake / Crosses
         (cp >= 0x2753 && cp <= 0x2757)   ||  // Question / Exclamation
         (cp >= 0x2763 && cp <= 0x2764)   ||  // Hearts
         (cp >= 0x2795 && cp <= 0x2797)   ||  // Plus / Minus
         (cp >= 0x27A1 && cp <= 0x27B0)   ||  // Arrows
         (cp >= 0x2620 && cp <= 0x2639)   ||  // Skull / Faces
         (cp >= 0x262A && cp <= 0x262A)   ||  // Crescent
         (cp >= 0x2638 && cp <= 0x263A)   ||  // Wheel / Smile
         (cp == 0x2640 || cp == 0x2642)   ||  // Gender
         (cp >= 0x2614 && cp <= 0x2618)   ||  // Umbrella / Shamrock
         (cp >= 0x261D && cp <= 0x261D)   ||  // Finger
         (cp >= 0x262E && cp <= 0x262F)   ||  // Peace / Yin-Yang
         (cp == 0x00A9 || cp == 0x00AE)   ||  // Copyright / Registered
         (cp == 0x2122 || cp == 0x2139)   ||  // TM / Info
         (cp == 0x23CF || cp == 0x23F0)   ||  // Eject / Alarm
         (cp == 0x24C2 || cp == 0x260E)   ||  // Circled M / Phone
         (cp == 0x2611 || cp == 0x267B)   ||  // Checkbox / Recycle
         (cp >= 0x1F200 && cp <= 0x1F251) ||  // Enclosed
         (cp >= 0x1F400 && cp <= 0x1F4FF);    // Symbols 2
}

static BOOL IsEmojiModifier(uint32_t cp) {
  return cp >= 0x1F3FB && cp <= 0x1F3FF;
}

static BOOL IsVariationSelector(uint32_t cp) {
  return cp == 0xFE0E || cp == 0xFE0F;
}

static BOOL IsRegionalIndicator(uint32_t cp) {
  return cp >= 0x1F1E6 && cp <= 0x1F1FF;
}

static BOOL IsKeycapBase(uint32_t cp) {
  return (cp >= '0' && cp <= '9') || cp == '#' || cp == '*';
}

static uint32_t CodepointAtIndex(NSString *text, NSUInteger idx, NSUInteger *advance) {
  NSUInteger len = [text length];
  if (idx >= len) { if (advance) *advance = 0; return 0; }
  unichar ch = [text characterAtIndex:idx];
  uint32_t cp = ch;
  NSUInteger adv = 1;
  if (ch >= 0xD800 && ch <= 0xDBFF && idx + 1 < len) {
    unichar lo = [text characterAtIndex:idx + 1];
    if (lo >= 0xDC00 && lo <= 0xDFFF) {
      cp = 0x10000 + ((ch - 0xD800) << 10) + (lo - 0xDC00);
      adv = 2;
    }
  }
  if (advance) *advance = adv;
  return cp;
}

static void AppendCodepointToString(NSMutableString *s, uint32_t cp) {
  if (cp <= 0xFFFF) {
    [s appendFormat:@"%C", (unichar)cp];
  } else {
    cp -= 0x10000;
    [s appendFormat:@"%C%C", (unichar)(0xD800 + (cp >> 10)), (unichar)(0xDC00 + (cp & 0x3FF))];
  }
}

static void AppendCodepointToEmojiKey(NSMutableString *key, uint32_t cp) {
  if ([key length] > 0) [key appendString:@"-"];
  [key appendFormat:@"%x", cp];
}

static NSString *EmojiKeyWithoutTextPresentation(NSString *key) {
  if (![key length]) return key;
  NSArray *parts = [key componentsSeparatedByString:@"-"];
  NSMutableArray *filtered = [NSMutableArray array];
  for (NSUInteger i = 0; i < [parts count]; i++) {
    NSString *p = [parts objectAtIndex:i];
    if (![p isEqualToString:@"fe0e"] && ![p isEqualToString:@"fe0f"]) [filtered addObject:p];
  }
  return [filtered componentsJoinedByString:@"-"];
}

NSArray *EmojiSegmentsFromText(NSString *text) {
  NSMutableArray *segs = [NSMutableArray array];
  if (![text length]) return segs;
  NSMutableString *buf = [NSMutableString string];
  NSUInteger len = [text length];
  for (NSUInteger i = 0; i < len; ) {
    NSUInteger adv = 1;
    uint32_t cp = CodepointAtIndex(text, i, &adv);
    BOOL keycap = NO;
    if (IsKeycapBase(cp)) {
      NSUInteger j = i + adv, adv2 = 0;
      uint32_t cp2 = CodepointAtIndex(text, j, &adv2);
      if (cp2 == 0xFE0F) {
        uint32_t cp3 = CodepointAtIndex(text, j + adv2, NULL);
        keycap = (cp3 == 0x20E3);
      } else {
        keycap = (cp2 == 0x20E3);
      }
    }
    if (IsEmojiCodepoint(cp) || keycap) {
      if ([buf length] > 0) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        [d setObject:@"text" forKey:@"type"]; [d setObject:[NSString stringWithString:buf] forKey:@"text"];
        [segs addObject:d];
        [buf setString:@""];
      }
      NSMutableString *key = [NSMutableString string];
      NSMutableString *raw = [NSMutableString string];
      AppendCodepointToEmojiKey(key, cp);
      AppendCodepointToString(raw, cp);
      i += adv;

      for (;;) {
        if (i >= len) break;
        NSUInteger nextAdv = 0;
        uint32_t next = CodepointAtIndex(text, i, &nextAdv);
        if (IsVariationSelector(next) || IsEmojiModifier(next) || next == 0x20E3) {
          AppendCodepointToEmojiKey(key, next);
          AppendCodepointToString(raw, next);
          i += nextAdv;
          continue;
        }
        if (next == 0x200D && i + nextAdv < len) {
          NSUInteger afterAdv = 0;
          uint32_t after = CodepointAtIndex(text, i + nextAdv, &afterAdv);
          if (IsEmojiCodepoint(after) || IsKeycapBase(after)) {
            AppendCodepointToEmojiKey(key, next);
            AppendCodepointToString(raw, next);
            i += nextAdv;
            AppendCodepointToEmojiKey(key, after);
            AppendCodepointToString(raw, after);
            i += afterAdv;
            continue;
          }
        }
        if (IsRegionalIndicator(cp) && IsRegionalIndicator(next)) {
          AppendCodepointToEmojiKey(key, next);
          AppendCodepointToString(raw, next);
          i += nextAdv;
        }
        break;
      }
      NSMutableDictionary *d = [NSMutableDictionary dictionary];
      [d setObject:@"emoji" forKey:@"type"];
      [d setObject:[NSNumber numberWithUnsignedInt:cp] forKey:@"codepoint"];
      [d setObject:key forKey:@"key"];
      [d setObject:raw forKey:@"text"];
      [segs addObject:d];
    } else {
      AppendCodepointToString(buf, cp);
      i += adv;
    }
  }
  if ([buf length] > 0) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:@"text" forKey:@"type"]; [d setObject:[NSString stringWithString:buf] forKey:@"text"];
    [segs addObject:d];
  }
  return segs;
}

static NSString *TwemojiBasePath() {
  static NSString *base = nil;
  if (!base) {
    // Check bundle first
    NSString *resPath = [[NSBundle mainBundle] resourcePath];
    NSString *bundleTwemoji = [resPath stringByAppendingPathComponent:@"twemoji"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bundleTwemoji]) {
      base = [bundleTwemoji copy];
    } else {
      // Fall back to app support
      NSString *support = [@"~/Library/Application Support/PowerPCTelegram/twemoji" stringByExpandingTildeInPath];
      base = [support copy];
    }
  }
  return base;
}

static NSMutableDictionary *sEmojiCache = nil;

NSImage *TwemojiImageForKey(NSString *emojiKey) {
  if (!sEmojiCache) sEmojiCache = [[NSMutableDictionary alloc] init];
  if (![emojiKey length]) return nil;
  NSString *key = [emojiKey lowercaseString];
  NSImage *cached = [sEmojiCache objectForKey:key];
  if (cached) return cached;

  NSArray *candidates = [NSArray arrayWithObjects:key, EmojiKeyWithoutTextPresentation(key), nil];
  for (NSUInteger i = 0; i < [candidates count]; i++) {
    NSString *candidate = [candidates objectAtIndex:i];
    if (![candidate length]) continue;
    NSString *filename = [candidate stringByAppendingString:@".png"];
    NSString *path = [TwemojiBasePath() stringByAppendingPathComponent:filename];
    NSImage *img = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    if (img) {
      [sEmojiCache setObject:img forKey:key];
      return img;
    }
    NSString *filenameUpper = [[candidate uppercaseString] stringByAppendingString:@".png"];
    NSString *pathUpper = [TwemojiBasePath() stringByAppendingPathComponent:filenameUpper];
    NSImage *img2 = [[[NSImage alloc] initWithContentsOfFile:pathUpper] autorelease];
    if (img2) {
      [sEmojiCache setObject:img2 forKey:key];
      return img2;
    }
  }
  return nil;
}

static NSImage *TwemojiImageForCodepoint(uint32_t cp) {
  return TwemojiImageForKey([NSString stringWithFormat:@"%x", cp]);
}

NSImage *TwemojiImageForSegment(NSDictionary *seg) {
  NSString *key = [seg objectForKey:@"key"];
  if ([key isKindOfClass:[NSString class]] && [key length]) return TwemojiImageForKey(key);
  uint32_t cp = (uint32_t)[[seg objectForKey:@"codepoint"] unsignedIntValue];
  return cp ? TwemojiImageForCodepoint(cp) : nil;
}

void DrawMissingEmojiGlyph(NSRect rect, NSColor *color) {
  NSRect r = NSInsetRect(rect, 1.5, 1.5);
  NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:3.0 yRadius:3.0];
  [[color colorWithAlphaComponent:0.18] setFill];
  [p fill];
  [[color colorWithAlphaComponent:0.45] setStroke];
  [p setLineWidth:1.0];
  [p stroke];
}

// Shared text layout — returns final y position (bottom of last line + lineHeight)
// If draw is NO, doesn't render, just measures.
static CGFloat LayoutEmojiText(NSArray *segments, NSRect bounds, NSColor *color, NSFont *font, BOOL draw) {
  CGFloat x = bounds.origin.x, y = bounds.origin.y;
  CGFloat maxX = bounds.origin.x + bounds.size.width;
  CGFloat lineHeight = ceil([font pointSize] * 1.35);
  CGFloat emojiSize = lineHeight;
  NSDictionary *textAttrs = nil;
  if (draw) textAttrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];

  for (NSUInteger i = 0; i < [segments count]; i++) {
    NSDictionary *seg = [segments objectAtIndex:i];
    NSString *type = StringOrEmpty([seg objectForKey:@"type"]);
    if ([type isEqualToString:@"text"]) {
      NSString *txt = [seg objectForKey:@"text"];
      if (![txt length]) continue;
      NSString *remaining = txt;
      while ([remaining length] > 0) {
        NSRange hardBreak = [remaining rangeOfString:@"\n"];
        BOOL hasHardBreak = (hardBreak.location != NSNotFound);
        NSString *source = hasHardBreak ? [remaining substringToIndex:hardBreak.location] : remaining;
        if (![source length] && hasHardBreak) {
          x = bounds.origin.x;
          y += lineHeight;
          remaining = [remaining substringFromIndex:hardBreak.location + hardBreak.length];
          continue;
        }
        CGFloat avail = maxX - x;
        if (avail < emojiSize) { x = bounds.origin.x; y += lineHeight; avail = maxX - x; }
        NSString *line = source;
        CGFloat lw = [line sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
        if (lw > avail && avail > 0) {
          if (x > bounds.origin.x) {
            x = bounds.origin.x;
            y += lineHeight;
            avail = maxX - x;
          }
          NSUInteger cut = [source length];
          NSString *candidate = source;
          while (cut > 1 && [candidate sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width > avail) {
            cut--;
            candidate = [source substringToIndex:cut];
          }
          NSRange space = [candidate rangeOfString:@" " options:NSBackwardsSearch];
          NSUInteger breakIndex = NSNotFound;
          if (space.location != NSNotFound && space.location > 0) breakIndex = space.location + 1;
          if (breakIndex != NSNotFound) {
            line = [source substringToIndex:breakIndex];
          } else {
            line = candidate;
          }
        }
        if (draw) [line drawAtPoint:NSMakePoint(x, y) withAttributes:textAttrs];
        CGFloat drawnW = [line sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
        x += drawnW;
        if ([line length] < [source length]) {
          remaining = [remaining substringFromIndex:[line length]];
          while ([remaining hasPrefix:@" "]) remaining = [remaining substringFromIndex:1];
          x = bounds.origin.x;
          y += lineHeight;
        } else if (hasHardBreak) {
          remaining = [remaining substringFromIndex:hardBreak.location + hardBreak.length];
          x = bounds.origin.x;
          y += lineHeight;
        } else {
          remaining = @"";
        }
      }
    } else {
      if (maxX - x < emojiSize) { x = bounds.origin.x; y += lineHeight; }
      NSImage *img = TwemojiImageForSegment(seg);
      if (img && draw) {
        NSRect er = NSMakeRect(x, y, emojiSize, emojiSize);
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *flip = [NSAffineTransform transform];
        [flip translateXBy:NSMinX(er) yBy:NSMaxY(er)];
        [flip scaleXBy:1.0 yBy:-1.0];
        [flip concat];
        [img drawInRect:NSMakeRect(0, 0, emojiSize, emojiSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
      } else if (!img && draw) {
        DrawMissingEmojiGlyph(NSMakeRect(x, y, emojiSize, emojiSize), color);
      }
      x += emojiSize;
    }
  }
  return y + lineHeight;
}

void DrawEmojiText(NSArray *segments, NSRect bounds, NSColor *color, NSFont *font) {
  if (bounds.size.width <= 0.0 || bounds.size.height <= 0.0) return;
  [NSGraphicsContext saveGraphicsState];
  [[NSBezierPath bezierPathWithRect:bounds] addClip];

  if ([segments count] == 1 && [[[segments objectAtIndex:0] objectForKey:@"type"] isEqualToString:@"text"]) {
    NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        font, NSFontAttributeName,
        color, NSForegroundColorAttributeName,
        style, NSParagraphStyleAttributeName,
        nil];
    NSString *txt = StringOrEmpty([[segments objectAtIndex:0] objectForKey:@"text"]);
    [txt drawInRect:bounds withAttributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
    return;
  }

  LayoutEmojiText(segments, bounds, color, font, YES);
  [NSGraphicsContext restoreGraphicsState];
}

void DrawSingleLineEmojiText(NSString *text, NSRect bounds, NSColor *color, NSFont *font) {
  if (![text length] || bounds.size.width <= 0.0 || bounds.size.height <= 0.0) return;
  [NSGraphicsContext saveGraphicsState];
  [[NSBezierPath bezierPathWithRect:bounds] addClip];

  NSArray *segments = EmojiSegmentsFromText(text);
  CGFloat x = bounds.origin.x;
  CGFloat y = bounds.origin.y;
  CGFloat maxX = bounds.origin.x + bounds.size.width;
  CGFloat lineHeight = ceil([font pointSize] * 1.35);
  CGFloat emojiSize = lineHeight;
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];

  for (NSUInteger i = 0; i < [segments count] && x < maxX; i++) {
    NSDictionary *seg = [segments objectAtIndex:i];
    NSString *type = StringOrEmpty([seg objectForKey:@"type"]);
    if ([type isEqualToString:@"text"]) {
      NSString *txt = [seg objectForKey:@"text"];
      if (![txt length]) continue;
      [txt drawAtPoint:NSMakePoint(x, y) withAttributes:attrs];
      x += ceil([font pointSize] * 0.58 * (CGFloat)[txt length]);
    } else {
      NSImage *img = TwemojiImageForSegment(seg);
      if (img) {
        NSRect er = NSMakeRect(x, y, emojiSize, emojiSize);
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *flip = [NSAffineTransform transform];
        [flip translateXBy:NSMinX(er) yBy:NSMaxY(er)];
        [flip scaleXBy:1.0 yBy:-1.0];
        [flip concat];
        [img drawInRect:NSMakeRect(0, 0, emojiSize, emojiSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
      } else {
        DrawMissingEmojiGlyph(NSMakeRect(x, y, emojiSize, emojiSize), color);
      }
      x += emojiSize;
    }
  }

  [NSGraphicsContext restoreGraphicsState];
}

NSString *TruncatedStringForWidth(NSString *text, NSDictionary *attrs, CGFloat maxWidth) {
  if (![text length] || maxWidth <= 0.0) return @"";
  NSFont *font = [attrs objectForKey:NSFontAttributeName];
  CGFloat pointSize = font ? [font pointSize] : 12.0;
  CGFloat avgCharWidth = pointSize * 0.62;
  NSUInteger maxChars = (NSUInteger)floor(maxWidth / avgCharWidth);
  if ([text length] <= maxChars) return text;
  if (maxChars <= 3) return @"...";

  NSRange safeRange = [text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maxChars - 3)];
  if (safeRange.length == 0) return @"...";
  return [[text substringWithRange:safeRange] stringByAppendingString:@"..."];
}
