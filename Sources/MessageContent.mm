#import "MessageContent.h"
#import "FoundationHelpers.h"

NSArray *LinkItemsFromTextAndEntities(NSString *text, NSArray *entities) {
  if (![text isKindOfClass:[NSString class]] || [text length] == 0) return [NSArray array];
  NSMutableArray *items = [NSMutableArray array];
  NSUInteger textLen = [text length];
  if ([entities isKindOfClass:[NSArray class]]) {
    for (NSUInteger i = 0; i < [entities count]; i++) {
      NSDictionary *ent = [entities objectAtIndex:i];
      if (![ent isKindOfClass:[NSDictionary class]]) continue;
      NSUInteger loc = (NSUInteger)LongLongValue([ent objectForKey:@"offset"]);
      NSUInteger len = (NSUInteger)LongLongValue([ent objectForKey:@"length"]);
      if (loc >= textLen || len == 0) continue;
      if (loc + len > textLen) len = textLen - loc;
      NSDictionary *type = [ent objectForKey:@"type"];
      NSString *typeName = StringOrEmpty([type objectForKey:@"@type"]);
      NSString *url = nil;
      if ([typeName isEqualToString:@"textEntityTypeTextUrl"]) {
        url = NormalizedURLString(StringOrEmpty([type objectForKey:@"url"]));
      } else if ([typeName isEqualToString:@"textEntityTypeUrl"]) {
        url = NormalizedURLString([text substringWithRange:NSMakeRange(loc, len)]);
      }
      if ([url length]) {
        [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithUnsignedInteger:loc], @"location",
          [NSNumber numberWithUnsignedInteger:len], @"length",
          url, @"url", nil]];
      }
    }
  }

  NSCharacterSet *stopSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSCharacterSet *trimSet = [NSCharacterSet characterSetWithCharactersInString:@".,!?;:)]}\"'"];
  for (NSUInteger i = 0; i < textLen; i++) {
    NSString *tail = [text substringFromIndex:i];
    NSString *lower = [tail lowercaseString];
    BOOL match = [lower hasPrefix:@"http://"] || [lower hasPrefix:@"https://"] || [lower hasPrefix:@"www."];
    if (!match) continue;
    NSUInteger end = i;
    while (end < textLen) {
      unichar ch = [text characterAtIndex:end];
      if ([stopSet characterIsMember:ch]) break;
      end++;
    }
    while (end > i && [trimSet characterIsMember:[text characterAtIndex:end - 1]]) end--;
    if (end <= i) continue;
    NSString *raw = [text substringWithRange:NSMakeRange(i, end - i)];
    NSString *url = NormalizedURLString(raw);
    if ([url length]) {
      [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger:i], @"location",
        [NSNumber numberWithUnsignedInteger:(end - i)], @"length",
        url, @"url", nil]];
    }
    i = end;
  }
  return items;
}

NSArray *LinkItemsForMessageContent(NSDictionary *content) {
  NSString *type = StringOrEmpty([content objectForKey:@"@type"]);
  NSDictionary *formatted = nil;
  if ([type isEqualToString:@"messageText"]) formatted = [content objectForKey:@"text"];
  else if ([type isEqualToString:@"messagePhoto"] || [type isEqualToString:@"messageVideo"]) formatted = [content objectForKey:@"caption"];
  NSString *text = StringOrEmpty([formatted objectForKey:@"text"]);
  NSArray *entities = [formatted objectForKey:@"entities"];
  return LinkItemsFromTextAndEntities(text, entities);
}

void DrawTextWithLinks(NSString *text, NSArray *links, NSRect rect, NSColor *textColor, NSColor *linkColor, NSFont *font) {
  if (![text length] || rect.size.width <= 0.0 || rect.size.height <= 0.0) return;
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [style setLineBreakMode:NSLineBreakByWordWrapping];
  NSMutableAttributedString *attr = [[[NSMutableAttributedString alloc] initWithString:text attributes:[NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName,
    textColor, NSForegroundColorAttributeName,
    style, NSParagraphStyleAttributeName,
    nil]] autorelease];
  NSUInteger textLen = [text length];
  if ([links isKindOfClass:[NSArray class]]) {
    for (NSUInteger i = 0; i < [links count]; i++) {
      NSDictionary *link = [links objectAtIndex:i];
      NSUInteger loc = (NSUInteger)LongLongValue([link objectForKey:@"location"]);
      NSUInteger len = (NSUInteger)LongLongValue([link objectForKey:@"length"]);
      if (loc >= textLen || len == 0) continue;
      if (loc + len > textLen) len = textLen - loc;
      [attr addAttribute:NSForegroundColorAttributeName value:linkColor range:NSMakeRange(loc, len)];
      [attr addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:NSMakeRange(loc, len)];
    }
  }
  [attr drawInRect:rect];
}

NSString *LinkURLAtPointInTextRect(NSString *text, NSArray *links, NSRect rect, NSPoint point, NSFont *font) {
  if (![text length] || ![links isKindOfClass:[NSArray class]] || [links count] == 0 || !NSPointInRect(point, rect)) return nil;
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [style setLineBreakMode:NSLineBreakByCharWrapping];
  NSTextStorage *storage = [[[NSTextStorage alloc] initWithString:text attributes:[NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName,
    style, NSParagraphStyleAttributeName,
    nil]] autorelease];
  NSLayoutManager *layout = [[[NSLayoutManager alloc] init] autorelease];
  NSTextContainer *container = [[[NSTextContainer alloc] initWithContainerSize:rect.size] autorelease];
  [container setLineFragmentPadding:0.0];
  [layout addTextContainer:container];
  [storage addLayoutManager:layout];
  [layout glyphRangeForTextContainer:container];

  NSPoint local = NSMakePoint(point.x - rect.origin.x, point.y - rect.origin.y);
  NSUInteger glyphIndex = [layout glyphIndexForPoint:local inTextContainer:container];
  NSUInteger charIndex = [layout characterIndexForGlyphAtIndex:glyphIndex];
  NSUInteger textLen = [text length];
  if (charIndex >= textLen && textLen > 0) charIndex = textLen - 1;
  for (NSUInteger i = 0; i < [links count]; i++) {
    NSDictionary *link = [links objectAtIndex:i];
    NSUInteger loc = (NSUInteger)LongLongValue([link objectForKey:@"location"]);
    NSUInteger len = (NSUInteger)LongLongValue([link objectForKey:@"length"]);
    if (len > 0 && charIndex >= loc && charIndex < loc + len) return StringOrEmpty([link objectForKey:@"url"]);
  }
  return nil;
}

NSString *MessagePreviewFromContent(NSDictionary *content) {
  NSString *type = StringOrEmpty([content objectForKey:@"@type"]);
  if ([type isEqualToString:@"messageText"]) {
    NSDictionary *text = [content objectForKey:@"text"];
    return StringOrEmpty([text objectForKey:@"text"]);
  }
  if ([type isEqualToString:@"messagePhoto"]) {
    NSDictionary *caption = [content objectForKey:@"caption"];
    NSString *c = StringOrEmpty([caption objectForKey:@"text"]);
    return [c length] ? [NSString stringWithFormat:@"[Photo] %@", c] : @"[Photo]";
  }
  if ([type isEqualToString:@"messageVideo"]) { return @"[Video]"; }
  if ([type isEqualToString:@"messageDocument"]) { return @"[Document]"; }
  if ([type isEqualToString:@"messageSticker"]) { return @"[Sticker]"; }
  if ([type isEqualToString:@"messageAnimation"]) { return @"[Animation]"; }
  if ([type isEqualToString:@"messageAudio"]) { return @"[Audio]"; }
  if ([type isEqualToString:@"messageVoiceNote"]) { return @"[Voice]"; }
  if ([type isEqualToString:@"messageChatAddMembers"]) { return @"[Members added]"; }
  if ([type isEqualToString:@"messageChatJoinByLink"]) { return @"[Joined by link]"; }
  if ([type isEqualToString:@"messageBasicGroupChatCreate"]) { return @"[Group created]"; }
  if ([type isEqualToString:@"messageUnsupported"]) { return @"[Unsupported]"; }
  return [NSString stringWithFormat:@"[%@]", type];
}

NSString *PreviewTextForMessage(NSDictionary *message) {
  NSDictionary *content = [message objectForKey:@"content"];
  if (content == nil) return @"";
  NSString *type = StringOrEmpty([content objectForKey:@"@type"]);
  if ([type isEqualToString:@"messageText"]) {
    return StringOrEmpty([[content objectForKey:@"text"] objectForKey:@"text"]);
  }
  if ([type isEqualToString:@"messagePhoto"] || [type isEqualToString:@"messageVideo"]) {
    NSString *c = StringOrEmpty([[content objectForKey:@"caption"] objectForKey:@"text"]);
    return [c length] ? c : @"";
  }
  return @"";
}

NSString *ContentTypeForMessage(NSDictionary *message) {
  NSDictionary *content = [message objectForKey:@"content"];
  if (content == nil) return @"text";
  return StringOrEmpty([content objectForKey:@"@type"]);
}

NSNumber *PhotoFileIdFromContent(NSDictionary *content) {
  if (content == nil || ![content isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *photo = [content objectForKey:@"photo"];
  if (![photo isKindOfClass:[NSDictionary class]]) return nil;
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) return nil;
  NSDictionary *best = nil;
  long long bestW = 0;
  for (NSUInteger i = 0; i < [sizes count]; i++) {
    NSDictionary *sz = [sizes objectAtIndex:i];
    if (![sz isKindOfClass:[NSDictionary class]]) continue;
    long long w = LongLongValue([sz objectForKey:@"width"]);
    NSDictionary *pf = [sz objectForKey:@"photo"];
    if (![pf isKindOfClass:[NSDictionary class]]) continue;
    if (best == nil || w > bestW) {
      best = sz; bestW = w;
    }
  }
  if (best == nil) return nil;
  id fileIdObj = [[best objectForKey:@"photo"] objectForKey:@"id"];
  if (![fileIdObj respondsToSelector:@selector(longLongValue)]) return nil;
  return [NSNumber numberWithLongLong:LongLongValue(fileIdObj)];
}

NSString *PhotoLocalPathFromContent(NSDictionary *content) {
  if (content == nil || ![content isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *photo = [content objectForKey:@"photo"];
  if (![photo isKindOfClass:[NSDictionary class]]) return nil;
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) return nil;
  NSDictionary *best = nil;
  long long bestW = 0;
  for (NSUInteger i = 0; i < [sizes count]; i++) {
    NSDictionary *sz = [sizes objectAtIndex:i];
    if (![sz isKindOfClass:[NSDictionary class]]) continue;
    NSDictionary *pf = [sz objectForKey:@"photo"];
    if (![pf isKindOfClass:[NSDictionary class]]) continue;
    long long w = LongLongValue([sz objectForKey:@"width"]);
    if (w > bestW) { best = sz; bestW = w; }
  }
  if (best == nil) return nil;
  NSString *path = StringOrEmpty([[[best objectForKey:@"photo"] objectForKey:@"local"] objectForKey:@"path"]);
  return [path length] ? path : nil;
}

long long PhotoWidthForContent(NSDictionary *content) {
  if (content == nil || ![content isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *photo = [content objectForKey:@"photo"];
  if (![photo isKindOfClass:[NSDictionary class]]) return 0;
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) return 0;
  long long bestW = 0;
  for (NSUInteger i = 0; i < [sizes count]; i++) {
    NSDictionary *sz = [sizes objectAtIndex:i];
    if (![sz isKindOfClass:[NSDictionary class]]) continue;
    if (![[sz objectForKey:@"photo"] isKindOfClass:[NSDictionary class]]) continue;
    long long w = LongLongValue([sz objectForKey:@"width"]);
    if (w > bestW) bestW = w;
  }
  return bestW;
}

long long PhotoHeightForContent(NSDictionary *content) {
  if (content == nil || ![content isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *photo = [content objectForKey:@"photo"];
  if (![photo isKindOfClass:[NSDictionary class]]) return 0;
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) return 0;
  long long bestW = 0, bestH = 0;
  for (NSUInteger i = 0; i < [sizes count]; i++) {
    NSDictionary *sz = [sizes objectAtIndex:i];
    if (![sz isKindOfClass:[NSDictionary class]]) continue;
    if (![[sz objectForKey:@"photo"] isKindOfClass:[NSDictionary class]]) continue;
    long long w = LongLongValue([sz objectForKey:@"width"]);
    if (w > bestW) { bestW = w; bestH = LongLongValue([sz objectForKey:@"height"]); }
  }
  return bestH;
}

long long PhotoSmallFileIdFromPhotoDict(NSDictionary *photo) {
  if (![photo isKindOfClass:[NSDictionary class]]) return 0;
  // Profile photo structure: "small" file object directly
  NSDictionary *smallFile = [photo objectForKey:@"small"];
  if ([smallFile isKindOfClass:[NSDictionary class]]) {
    return LongLongValue([smallFile objectForKey:@"id"]);
  }
  // Message photo structure: "sizes" array of photoSize objects
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if ([sizes isKindOfClass:[NSArray class]] && [sizes count] > 0) {
    long long bestW = 1LL << 62;
    long long bestId = 0;
    for (NSUInteger i = 0; i < [sizes count]; i++) {
      NSDictionary *sz = [sizes objectAtIndex:i];
      if (![sz isKindOfClass:[NSDictionary class]]) continue;
      NSDictionary *pf = [sz objectForKey:@"photo"];
      if (![pf isKindOfClass:[NSDictionary class]]) continue;
      long long w = LongLongValue([sz objectForKey:@"width"]);
      long long fid = LongLongValue([pf objectForKey:@"id"]);
      if (w < bestW && fid != 0) { bestW = w; bestId = fid; }
    }
    return bestId;
  }
  return 0;
}

NSString *ProfilePhotoLocalPath(NSDictionary *profilePhoto) {
  if (![profilePhoto isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *smallFile = [profilePhoto objectForKey:@"small"];
  if (![smallFile isKindOfClass:[NSDictionary class]]) return nil;
  NSString *path = StringOrEmpty([[smallFile objectForKey:@"local"] objectForKey:@"path"]);
  if ([path length] > 0) return path;
  return nil;
}

NSDictionary *LargestPhotoSizeFromPhotoDict(NSDictionary *photo) {
  if (![photo isKindOfClass:[NSDictionary class]]) return nil;
  NSArray *sizes = [photo objectForKey:@"sizes"];
  if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) return nil;
  long long bestW = 0;
  NSDictionary *bestSize = nil;
  for (NSUInteger i = 0; i < [sizes count]; i++) {
    NSDictionary *sz = [sizes objectAtIndex:i];
    if (![sz isKindOfClass:[NSDictionary class]]) continue;
    NSDictionary *pf = [sz objectForKey:@"photo"];
    if (![pf isKindOfClass:[NSDictionary class]]) continue;
    long long w = LongLongValue([sz objectForKey:@"width"]);
    if (w > bestW) { bestW = w; bestSize = sz; }
  }
  return bestSize;
}

NSDictionary *LargestPhotoFileFromPhotoDict(NSDictionary *photo) {
  NSDictionary *size = LargestPhotoSizeFromPhotoDict(photo);
  NSDictionary *file = [size objectForKey:@"photo"];
  return [file isKindOfClass:[NSDictionary class]] ? file : nil;
}

long long ThumbnailFileIdFromDict(NSDictionary *thumb) {
  if (![thumb isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *file = [thumb objectForKey:@"file"];
  return [file isKindOfClass:[NSDictionary class]] ? LongLongValue([file objectForKey:@"id"]) : 0;
}

NSString *ThumbnailLocalPathFromDict(NSDictionary *thumb) {
  if (![thumb isKindOfClass:[NSDictionary class]]) return nil;
  NSString *path = StringOrEmpty([[[thumb objectForKey:@"file"] objectForKey:@"local"] objectForKey:@"path"]);
  return [path length] ? path : nil;
}

BOOL PreviewImageFromDictRecursive(NSDictionary *dict, int depth, long long *fidOut, NSString **pathOut, long long *widthOut, long long *heightOut) {
  if (![dict isKindOfClass:[NSDictionary class]] || depth > 4) return NO;

  long long fid = 0;
  NSString *path = nil;
  long long width = 0, height = 0;
  NSDictionary *photoSize = LargestPhotoSizeFromPhotoDict(dict);
  if ([photoSize isKindOfClass:[NSDictionary class]]) {
    NSDictionary *file = [photoSize objectForKey:@"photo"];
    fid = LongLongValue([file objectForKey:@"id"]);
    path = StringOrEmpty([[file objectForKey:@"local"] objectForKey:@"path"]);
    width = LongLongValue([photoSize objectForKey:@"width"]);
    height = LongLongValue([photoSize objectForKey:@"height"]);
  }
  if (fid) {
    if (fidOut) *fidOut = fid;
    if (pathOut) *pathOut = path;
    if (widthOut) *widthOut = width;
    if (heightOut) *heightOut = height;
    return YES;
  }

  NSDictionary *photo = [dict objectForKey:@"photo"];
  if (PreviewImageFromDictRecursive(photo, depth + 1, fidOut, pathOut, widthOut, heightOut)) return YES;

  NSArray *keys = [NSArray arrayWithObjects:@"type", @"video", @"animation", @"document", @"audio", @"page_block", nil];
  for (NSUInteger i = 0; i < [keys count]; i++) {
    NSDictionary *child = [dict objectForKey:[keys objectAtIndex:i]];
    if (PreviewImageFromDictRecursive(child, depth + 1, fidOut, pathOut, widthOut, heightOut)) return YES;
  }

  if (!fid) {
    fid = ThumbnailFileIdFromDict(dict);
    path = ThumbnailLocalPathFromDict(dict);
    width = LongLongValue([dict objectForKey:@"width"]);
    height = LongLongValue([dict objectForKey:@"height"]);
  }
  if (fid) {
    if (fidOut) *fidOut = fid;
    if (pathOut) *pathOut = path;
    if (widthOut) *widthOut = width;
    if (heightOut) *heightOut = height;
    return YES;
  }

  NSDictionary *thumb = [dict objectForKey:@"thumbnail"];
  if (PreviewImageFromDictRecursive(thumb, depth + 1, fidOut, pathOut, widthOut, heightOut)) return YES;
  return NO;
}

long long PreviewImageFileIdFromWebPageDict(NSDictionary *webPage, NSString **localPathOut, long long *widthOut, long long *heightOut) {
  long long fid = 0;
  NSString *path = nil;
  long long width = 0, height = 0;
  if (PreviewImageFromDictRecursive(webPage, 0, &fid, &path, &width, &height)) {
    if (localPathOut) *localPathOut = path;
    if (widthOut) *widthOut = width;
    if (heightOut) *heightOut = height;
    return fid;
  }
  if (localPathOut) *localPathOut = nil;
  if (widthOut) *widthOut = 0;
  if (heightOut) *heightOut = 0;
  return 0;
}

long long VideoThumbnailFileId(NSDictionary *content) {
  if (![content isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *video = [content objectForKey:@"video"];
  if (![video isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *thumb = [video objectForKey:@"thumbnail"];
  return ThumbnailFileIdFromDict(thumb);
}

long long VideoFileId(NSDictionary *content) {
  if (![content isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *video = [content objectForKey:@"video"];
  if (![video isKindOfClass:[NSDictionary class]]) return 0;
  NSDictionary *file = [video objectForKey:@"video"];
  if (![file isKindOfClass:[NSDictionary class]]) return 0;
  return LongLongValue([file objectForKey:@"id"]);
}

NSString *VideoThumbnailLocalPath(NSDictionary *content) {
  if (![content isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *video = [content objectForKey:@"video"];
  if (![video isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *thumb = [video objectForKey:@"thumbnail"];
  return ThumbnailLocalPathFromDict(thumb);
}

NSComparisonResult CompareOrderStrings(NSString *lhs, NSString *rhs) {
  NSUInteger llen = [lhs length], rlen = [rhs length];
  if (llen > rlen) return NSOrderedAscending;
  if (llen < rlen) return NSOrderedDescending;
  return [rhs compare:lhs];
}

NSInteger CompareChatIds(id lhs, id rhs, void *context) {
  NSDictionary *chatsById = (NSDictionary *)context;
  NSDictionary *left = [chatsById objectForKey:lhs], *right = [chatsById objectForKey:rhs];
  NSComparisonResult o = CompareOrderStrings(StringOrEmpty([left objectForKey:@"order"]), StringOrEmpty([right objectForKey:@"order"]));
  if (o != NSOrderedSame) return o;
  return [StringOrEmpty([left objectForKey:@"title"]) compare:StringOrEmpty([right objectForKey:@"title"])];
}

NSInteger CompareMessagesById(id lhs, id rhs, void *context) {
  (void)context;
  long long lid = LongLongValue([lhs objectForKey:@"id"]), rid = LongLongValue([rhs objectForKey:@"id"]);
  return lid < rid ? NSOrderedAscending : (lid > rid ? NSOrderedDescending : NSOrderedSame);
}

CGFloat TextHeightForWidth(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines) {
  if ([text length] == 0) return 0;
  CGFloat lh = ceil([font pointSize] * 1.35);
  if (maxWidth < 10.0) return lh;
  static NSMutableDictionary *heightCache = nil;
  static NSMutableArray *heightOrder = nil;
  if (!heightCache) {
    heightCache = [[NSMutableDictionary alloc] init];
    heightOrder = [[NSMutableArray alloc] init];
  }
  NSUInteger textHash = [text hash];
  NSString *key = [NSString stringWithFormat:@"%u:%u:%d:%lu:%lu",
    (unsigned)ceil(maxWidth), (unsigned)ceil([font pointSize] * 10.0), maxLines,
    (unsigned long)[text length], (unsigned long)textHash];
  NSNumber *cached = [heightCache objectForKey:key];
  if (cached) {
    [heightOrder removeObject:key];
    [heightOrder addObject:key];
    return [cached doubleValue];
  }
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [style setLineBreakMode:NSLineBreakByWordWrapping];
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
      font, NSFontAttributeName,
      style, NSParagraphStyleAttributeName,
      nil];
  NSRect r = [text boundingRectWithSize:NSMakeSize(maxWidth, 100000.0)
                                options:NSStringDrawingUsesLineFragmentOrigin
                             attributes:attrs];
  CGFloat h = ceil(r.size.height) + 3.0;
  if (h < lh) h = lh;
  if (maxLines > 0) {
    CGFloat cap = (CGFloat)maxLines * lh + 3.0;
    if (h > cap) h = cap;
  }
  [heightCache setObject:[NSNumber numberWithDouble:h] forKey:key];
  [heightOrder addObject:key];
  while ([heightOrder count] > 700) {
    NSString *oldest = [[[heightOrder objectAtIndex:0] retain] autorelease];
    [heightCache removeObjectForKey:oldest];
    [heightOrder removeObjectAtIndex:0];
  }
  return h;
}

CGFloat TextHeightForWidthAndBreakMode(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines, NSLineBreakMode mode) {
  if ([text length] == 0) return 0;
  CGFloat lh = ceil([font pointSize] * 1.35);
  if (maxWidth < 10.0) return lh;
  static NSMutableDictionary *heightCache = nil;
  static NSMutableArray *heightOrder = nil;
  if (!heightCache) {
    heightCache = [[NSMutableDictionary alloc] init];
    heightOrder = [[NSMutableArray alloc] init];
  }
  NSUInteger textHash = [text hash];
  NSString *key = [NSString stringWithFormat:@"%u:%u:%d:%d:%lu:%lu",
    (unsigned)ceil(maxWidth), (unsigned)ceil([font pointSize] * 10.0), maxLines, (int)mode,
    (unsigned long)[text length], (unsigned long)textHash];
  NSNumber *cached = [heightCache objectForKey:key];
  if (cached) {
    [heightOrder removeObject:key];
    [heightOrder addObject:key];
    return [cached doubleValue];
  }
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [style setLineBreakMode:mode];
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
      font, NSFontAttributeName,
      style, NSParagraphStyleAttributeName,
      nil];
  NSRect r = [text boundingRectWithSize:NSMakeSize(maxWidth, 100000.0)
                                options:NSStringDrawingUsesLineFragmentOrigin
                             attributes:attrs];
  CGFloat h = ceil(r.size.height) + 3.0;
  if (h < lh) h = lh;
  if (maxLines > 0) {
    CGFloat cap = (CGFloat)maxLines * lh + 3.0;
    if (h > cap) h = cap;
  }
  [heightCache setObject:[NSNumber numberWithDouble:h] forKey:key];
  [heightOrder addObject:key];
  while ([heightOrder count] > 500) {
    NSString *oldest = [[[heightOrder objectAtIndex:0] retain] autorelease];
    [heightCache removeObjectForKey:oldest];
    [heightOrder removeObjectAtIndex:0];
  }
  return h;
}

CGFloat TextHeightForWidthUncapped(NSString *text, NSFont *font, CGFloat maxWidth) {
  return TextHeightForWidth(text, font, maxWidth, 0);
}

CGFloat MessageBubbleMaxWidthForColumnWidth(CGFloat columnWidth, BOOL isOutgoing) {
  CGFloat reserved = isOutgoing ? 24.0 : 58.0;
  CGFloat w = columnWidth - reserved;
  if (w < columnWidth - 24.0 && columnWidth < 360.0) w = columnWidth - 24.0;
  if (w < 120.0) w = columnWidth - 16.0;
  if (w < 80.0) w = 80.0;
  return w;
}

NSUInteger EstimatedLineCountForText(NSString *text, NSFont *font, CGFloat maxWidth) {
  if (![text length]) return 0;
  CGFloat avgCharW = [font pointSize] * 0.52;
  NSUInteger charsPerLine = (maxWidth < avgCharW) ? 1 : (NSUInteger)floor(maxWidth / avgCharW);
  if (charsPerLine < 1) charsPerLine = 1;
  NSUInteger lines = 1;
  NSUInteger col = 0;
  for (NSUInteger i = 0; i < [text length]; i++) {
    unichar ch = [text characterAtIndex:i];
    if (ch == '\n') { lines++; col = 0; continue; }
    col++;
    if (col >= charsPerLine) { lines++; col = 0; }
  }
  return lines;
}

CGFloat FastTextHeightEstimate(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines) {
  if (![text length]) return 0.0;
  CGFloat lh = ceil([font pointSize] * 1.35);
  NSUInteger lines = EstimatedLineCountForText(text, font, maxWidth);
  if (maxLines > 0 && lines > (NSUInteger)maxLines) lines = (NSUInteger)maxLines;
  if (lines < 1) lines = 1;
  return ((CGFloat)lines * lh) + 8.0;
}

NSString *TruncatedText(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines) {
  if (![text length] || maxLines <= 0) return text;
  CGFloat avgCharW = [font pointSize] * 0.68;
  NSUInteger charsPerLine = (maxWidth < avgCharW) ? 1 : (NSUInteger)(maxWidth / avgCharW);
  NSUInteger lines = 0, pos = 0, len = [text length];
  while (pos < len && (int)lines < maxLines) {
    lines++;
    NSUInteger end = pos;
    while (end < len) {
      unichar ch = [text characterAtIndex:end];
      if (ch == '\n') { end++; break; }
      end++;
      if (end - pos >= charsPerLine) break;
    }
    if (end == pos) pos++; else pos = end;
  }
  if (pos >= len) return text;
  NSString *prefix = [text substringToIndex:pos];
  NSRange space = [prefix rangeOfString:@" " options:NSBackwardsSearch];
  if (space.location != NSNotFound && space.location > 0) prefix = [prefix substringToIndex:space.location];
  while ([prefix length] > 0) {
    unichar ch = [prefix characterAtIndex:[prefix length] - 1];
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:ch]) prefix = [prefix substringToIndex:[prefix length] - 1];
    else break;
  }
  return [prefix stringByAppendingString:@"..."];
}

NSString *NormalizePreviewDescription(NSString *desc) {
  if (![desc isKindOfClass:[NSString class]] || [desc length] == 0) return @"";
  NSArray *parts = [desc componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSMutableArray *clean = [NSMutableArray array];
  for (NSUInteger i = 0; i < [parts count]; i++) {
    NSString *p = [parts objectAtIndex:i];
    if ([p length] > 0) [clean addObject:p];
  }
  NSString *s = [clean componentsJoinedByString:@" "];
  NSUInteger maxLen = 180;
  if ([s length] <= maxLen) return s;
  NSRange cutRange = NSMakeRange(0, maxLen);
  NSString *prefix = [s substringWithRange:cutRange];
  NSRange lastSpace = [prefix rangeOfString:@" " options:NSBackwardsSearch];
  if (lastSpace.location != NSNotFound && lastSpace.location > 80) {
    prefix = [prefix substringToIndex:lastSpace.location];
  }
  while ([prefix length] > 0) {
    unichar ch = [prefix characterAtIndex:[prefix length] - 1];
    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch] || [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:ch]) {
      prefix = [prefix substringToIndex:[prefix length] - 1];
    } else {
      break;
    }
  }
  return [prefix stringByAppendingString:@"..."];
}

CGFloat WebPreviewTextHeight(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines) {
  return TextHeightForWidthAndBreakMode(text, font, maxWidth, maxLines, NSLineBreakByWordWrapping);
}

CGFloat ReactionBadgesHeight(NSArray *rxs, CGFloat contentWidth);
CGFloat EstimatedReactionBadgesHeightForCount(NSUInteger count, CGFloat contentWidth);

NSSize WebPreviewImageSize(CGFloat maxWidth, long long imageWidth, long long imageHeight) {
  if (maxWidth <= 0.0) return NSMakeSize(0.0, 0.0);
  if (imageWidth > 0 && imageHeight > 0) {
    CGFloat s = 1.0;
    if ((CGFloat)imageWidth > maxWidth) s = maxWidth / (CGFloat)imageWidth;
    if ((CGFloat)imageHeight * s > 220.0) s = 220.0 / (CGFloat)imageHeight;
    CGFloat w = floor((CGFloat)imageWidth * s);
    CGFloat h = floor((CGFloat)imageHeight * s);
    if (w < 1.0) w = 1.0;
    if (h < 1.0) h = 1.0;
    return NSMakeSize(w, h);
  }
  CGFloat h = maxWidth * 0.52;
  if (h < 86.0) h = 86.0;
  if (h > 180.0) h = 180.0;
  return NSMakeSize(maxWidth, h);
}

CGFloat MaxMediaPreviewHeightForContentType(NSString *contentType) {
  return [contentType isEqualToString:@"messagePhoto"] ? 360.0 : 240.0;
}

NSSize MediaPreviewSize(CGFloat maxWidth, long long imageWidth, long long imageHeight, NSString *contentType) {
  if (maxWidth <= 0.0) return NSMakeSize(0.0, 0.0);
  if (imageWidth <= 0 || imageHeight <= 0) return NSMakeSize(0.0, 0.0);
  CGFloat scale = 1.0;
  if ((CGFloat)imageWidth > maxWidth) scale = maxWidth / (CGFloat)imageWidth;
  CGFloat maxH = MaxMediaPreviewHeightForContentType(contentType);
  if ((CGFloat)imageHeight * scale > maxH) scale = maxH / (CGFloat)imageHeight;
  CGFloat w = floor((CGFloat)imageWidth * scale);
  CGFloat h = floor((CGFloat)imageHeight * scale);
  if (w < 1.0) w = 1.0;
  if (h < 1.0) h = 1.0;
  return NSMakeSize(w, h);
}

CGFloat WebPreviewCardHeight(CGFloat cardWidth, BOOL hasPhoto, long long imageWidth, long long imageHeight, NSString *site, NSString *title, NSString *desc) {
  if (cardWidth <= 0.0) return 0.0;
  NSString *cleanDesc = NormalizePreviewDescription(desc);
  CGFloat pad = 8.0;
  CGFloat innerW = cardWidth - pad * 2.0;
  if (innerW < 24.0) innerW = cardWidth;
  CGFloat h = pad;
  if ([site length]) h += 12.0 + 5.0;
  if (hasPhoto) {
    NSSize ps = WebPreviewImageSize(innerW, imageWidth, imageHeight);
    h += ps.height + 7.0;
  }
  if ([title length]) h += WebPreviewTextHeight(title, [NSFont boldSystemFontOfSize:11], innerW, 2) + 4.0;
  if ([cleanDesc length]) h += WebPreviewTextHeight(cleanDesc, [NSFont systemFontOfSize:10], innerW, 4);
  h += pad;
  return h < 34.0 ? 34.0 : h;
}

CGFloat EstimatedCellHeightForDict(NSDictionary *dict, CGFloat columnWidth) {
  BOOL isOut = [[dict objectForKey:@"isOutgoing"] boolValue];
  CGFloat maxBubbleWidth = MessageBubbleMaxWidthForColumnWidth(columnWidth, isOut);
  CGFloat h = 16.0;
  NSString *reply = StringOrEmpty([dict objectForKey:@"replyPreview"]);
  if ([reply length] > 0) {
    CGFloat qh = TextHeightForWidth(reply, [NSFont systemFontOfSize:9], maxBubbleWidth - 23.0, 2) + 4.0;
    h += qh < 18.0 ? 18.0 : qh;
  }
  NSString *ct = StringOrEmpty([dict objectForKey:@"contentType"]);
  if ([ct isEqualToString:@"messageText"]) {
    NSString *txt = StringOrEmpty([dict objectForKey:@"text"]);
    BOOL isLong = [[dict objectForKey:@"isLongMessage"] boolValue];
    BOOL expanded = [[dict objectForKey:@"isExpanded"] boolValue];
    if (isLong && !expanded) {
      h += TextHeightForWidth(txt, [NSFont systemFontOfSize:12], maxBubbleWidth - 16.0, 6);
      h += 14.0;
    } else {
      h += TextHeightForWidthUncapped(txt, [NSFont systemFontOfSize:12], maxBubbleWidth - 16.0);
    }
  } else if ([ct isEqualToString:@"messagePhoto"] || [ct isEqualToString:@"messageVideo"]) {
    long long pw = LongLongValue([dict objectForKey:@"imageWidth"]);
    long long ph = LongLongValue([dict objectForKey:@"imageHeight"]);
    if (pw > 0 && ph > 0) {
      NSSize ps = MediaPreviewSize(maxBubbleWidth - 16.0, pw, ph, ct);
      h += ps.height;
    } else { h += 80.0; }
    NSString *cap = StringOrEmpty([dict objectForKey:@"text"]);
    if ([cap length] > 0) h += 4.0 + TextHeightForWidthUncapped(cap, [NSFont systemFontOfSize:12], maxBubbleWidth - 16.0);
  } else if ([ct isEqualToString:@"messageSticker"]) {
    h += 80.0;
  } else {
    NSString *t = StringOrEmpty([dict objectForKey:@"text"]);
    if ([t length] > 0) h += TextHeightForWidthUncapped(t, [NSFont systemFontOfSize:12], maxBubbleWidth - 16.0);
  }
  // Web page preview card
  if (StringOrEmpty([dict objectForKey:@"webPageUrl"]).length > 0) {
    NSString *wpt = StringOrEmpty([dict objectForKey:@"webPageTitle"]);
    NSString *wpd = StringOrEmpty([dict objectForKey:@"webPageDescription"]);
    NSString *wps = StringOrEmpty([dict objectForKey:@"webPageSite"]);
    BOOL hasPhoto = ([dict objectForKey:@"webPagePhotoPath"] != nil || [dict objectForKey:@"webPagePhotoId"] != nil);
    h += 8.0 + WebPreviewCardHeight(maxBubbleWidth - 16.0, hasPhoto, LongLongValue([dict objectForKey:@"webPagePhotoWidth"]), LongLongValue([dict objectForKey:@"webPagePhotoHeight"]), wps, wpt, wpd);
  }
  // Reactions badges
  NSArray *rx = [dict objectForKey:@"reactions"];
  if ([rx count] > 0) h += ReactionBadgesHeight(rx, maxBubbleWidth - 16.0);
  return h + 14.0 + 24.0;
}

CGFloat EstimatedReactionBadgeWidth(NSDictionary *rx) {
  NSString *countStr = [NSString stringWithFormat:@" %d", (int)LongLongValue([rx objectForKey:@"count"])];
  NSSize cs = [countStr sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:10] forKey:NSFontAttributeName]];
  return 14.0 + cs.width + 10.0;
}

CGFloat ReactionBadgesHeight(NSArray *rxs, CGFloat contentWidth) {
  if (![rxs isKindOfClass:[NSArray class]] || [rxs count] == 0) return 0.0;
  CGFloat x = 0.0;
  NSUInteger rows = 1;
  for (NSUInteger i = 0; i < [rxs count]; i++) {
    NSDictionary *rx = [rxs objectAtIndex:i];
    CGFloat bw = EstimatedReactionBadgeWidth(rx);
    if (x > 0.0 && x + bw > contentWidth) { rows++; x = 0.0; }
    x += bw + 4.0;
  }
  return (CGFloat)rows * 22.0 + 4.0;
}

CGFloat EstimatedReactionBadgesHeightForCount(NSUInteger count, CGFloat contentWidth) {
  if (count == 0) return 0.0;
  CGFloat averageBadge = 44.0;
  NSUInteger perRow = (NSUInteger)floor(contentWidth / averageBadge);
  if (perRow < 1) perRow = 1;
  NSUInteger rows = (count + perRow - 1) / perRow;
  return (CGFloat)rows * 22.0 + 4.0;
}
