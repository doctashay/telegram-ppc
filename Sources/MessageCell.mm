#import "MessageCell.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MessageContent.h"

@implementation MessageCell

- (id)init {
  self = [super init];
  if (self) {
    senderName_ = @""; messageText_ = @""; isOutgoing_ = NO;
    timestampStr_ = @""; contentType_ = @"text"; imagePath_ = nil;
    imageWidth_ = 0; imageHeight_ = 0; fileDownloadPriority_ = 0; hideMediaThumbnail_ = NO;
    fileIdToDownload_ = nil; maxWidth_ = 300;
    senderAvatarPath_ = nil; senderInitial_ = @""; replyPreview_ = nil;
    isLongMessage_ = NO; isExpanded_ = NO; messageId_ = 0;
    webPageUrl_ = nil; webPageTitle_ = nil; webPageDescription_ = nil;
    webPageSite_ = nil; webPagePhotoPath_ = nil; webPagePhotoWidth_ = 0; webPagePhotoHeight_ = 0; webPageHasPhoto_ = NO;
    linkItems_ = nil; reactions_ = nil;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone {
  MessageCell *c = [super copyWithZone:zone];
  c->senderName_ = [senderName_ copy]; c->messageText_ = [messageText_ copy];
  c->isOutgoing_ = isOutgoing_; c->timestampStr_ = [timestampStr_ copy];
  c->contentType_ = [contentType_ copy]; c->imagePath_ = [imagePath_ copy];
  c->imageWidth_ = imageWidth_; c->imageHeight_ = imageHeight_;
  c->fileDownloadPriority_ = fileDownloadPriority_; c->fileIdToDownload_ = [fileIdToDownload_ copy];
  c->hideMediaThumbnail_ = hideMediaThumbnail_;
  c->maxWidth_ = maxWidth_;
  c->senderAvatarPath_ = [senderAvatarPath_ copy]; c->senderInitial_ = [senderInitial_ copy];
  c->replyPreview_ = [replyPreview_ copy];
  c->isLongMessage_ = isLongMessage_; c->isExpanded_ = isExpanded_; c->messageId_ = messageId_;
  c->webPageUrl_ = [webPageUrl_ copy]; c->webPageTitle_ = [webPageTitle_ copy];
  c->webPageDescription_ = [webPageDescription_ copy]; c->webPageSite_ = [webPageSite_ copy];
  c->webPagePhotoPath_ = [webPagePhotoPath_ copy];
  c->webPagePhotoWidth_ = webPagePhotoWidth_;
  c->webPagePhotoHeight_ = webPagePhotoHeight_;
  c->webPageHasPhoto_ = webPageHasPhoto_;
  c->linkItems_ = [linkItems_ retain];
  c->reactions_ = [reactions_ retain];
  return c;
}

- (void)dealloc {
  [senderName_ release]; [messageText_ release]; [timestampStr_ release];
  [contentType_ release]; [imagePath_ release]; [fileIdToDownload_ release];
  [senderAvatarPath_ release]; [senderInitial_ release]; [replyPreview_ release];
  [webPageUrl_ release]; [webPageTitle_ release]; [webPageDescription_ release];
  [webPageSite_ release]; [webPagePhotoPath_ release]; [linkItems_ release]; [reactions_ release];
  [super dealloc];
}

- (void)configureWithMessageDict:(NSDictionary *)dict {
  if (senderName_) [senderName_ release];
  senderName_ = [StringOrEmpty([dict objectForKey:@"senderName"]) copy];
  if (messageText_) [messageText_ release];
  messageText_ = [StringOrEmpty([dict objectForKey:@"text"]) copy];
  isOutgoing_ = [[dict objectForKey:@"isOutgoing"] boolValue];
  if (timestampStr_) [timestampStr_ release];
  timestampStr_ = [StringOrEmpty([dict objectForKey:@"timestamp"]) copy];
  if (contentType_) [contentType_ release];
  contentType_ = [StringOrEmpty([dict objectForKey:@"contentType"]) copy];
  if (imagePath_) { [imagePath_ release]; imagePath_ = nil; }
  NSString *ip = [dict objectForKey:@"imagePath"];
  if ([ip isKindOfClass:[NSString class]] && [ip length] > 0) imagePath_ = [ip copy];
  imageWidth_ = LongLongValue([dict objectForKey:@"imageWidth"]);
  imageHeight_ = LongLongValue([dict objectForKey:@"imageHeight"]);
  fileDownloadPriority_ = [[dict objectForKey:@"fileDownloadPriority"] intValue];
  hideMediaThumbnail_ = [[dict objectForKey:@"hideMediaThumbnail"] boolValue];
  if (fileIdToDownload_) { [fileIdToDownload_ release]; fileIdToDownload_ = nil; }
  NSNumber *fid = [dict objectForKey:@"fileIdToDownload"];
  if ([fid isKindOfClass:[NSNumber class]]) fileIdToDownload_ = [fid copy];
  maxWidth_ = (CGFloat)LongLongValue([dict objectForKey:@"maxWidth"]);
  if (maxWidth_ < 100.0) maxWidth_ = 300.0;
  if (senderAvatarPath_) { [senderAvatarPath_ release]; senderAvatarPath_ = nil; }
  NSString *ap = [dict objectForKey:@"avatarPath"];
  if ([ap isKindOfClass:[NSString class]] && [ap length] > 0) senderAvatarPath_ = [ap copy];
  if (senderInitial_) [senderInitial_ release];
  senderInitial_ = [StringOrEmpty([dict objectForKey:@"senderInitial"]) copy];
  if (replyPreview_) [replyPreview_ release];
  replyPreview_ = [StringOrEmpty([dict objectForKey:@"replyPreview"]) copy];
  if (![replyPreview_ length]) { [replyPreview_ release]; replyPreview_ = nil; }
  isLongMessage_ = [[dict objectForKey:@"isLongMessage"] boolValue];
  isExpanded_ = [[dict objectForKey:@"isExpanded"] boolValue];
  messageId_ = LongLongValue([dict objectForKey:@"messageId"]);
  if (webPageUrl_) { [webPageUrl_ release]; webPageUrl_ = nil; }
  NSString *wpu = [dict objectForKey:@"webPageUrl"];
  if ([wpu isKindOfClass:[NSString class]] && [wpu length] > 0) webPageUrl_ = [wpu copy];
  if (webPageTitle_) { [webPageTitle_ release]; webPageTitle_ = nil; }
  NSString *wpt = [dict objectForKey:@"webPageTitle"];
  if ([wpt isKindOfClass:[NSString class]]) webPageTitle_ = [wpt copy];
  if (webPageDescription_) { [webPageDescription_ release]; webPageDescription_ = nil; }
  NSString *wpd = [dict objectForKey:@"webPageDescription"];
  if ([wpd isKindOfClass:[NSString class]]) webPageDescription_ = [wpd copy];
  if (webPageSite_) { [webPageSite_ release]; webPageSite_ = nil; }
  NSString *wps = [dict objectForKey:@"webPageSite"];
  if ([wps isKindOfClass:[NSString class]]) webPageSite_ = [wps copy];
  if (webPagePhotoPath_) { [webPagePhotoPath_ release]; webPagePhotoPath_ = nil; }
  NSString *wppp = [dict objectForKey:@"webPagePhotoPath"];
  if ([wppp isKindOfClass:[NSString class]] && [wppp length] > 0) webPagePhotoPath_ = [wppp copy];
  webPagePhotoWidth_ = LongLongValue([dict objectForKey:@"webPagePhotoWidth"]);
  webPagePhotoHeight_ = LongLongValue([dict objectForKey:@"webPagePhotoHeight"]);
  webPageHasPhoto_ = (webPagePhotoPath_ != nil || [dict objectForKey:@"webPagePhotoId"] != nil);
  if (linkItems_) { [linkItems_ release]; linkItems_ = nil; }
  NSArray *links = [dict objectForKey:@"linkItems"];
  if ([links isKindOfClass:[NSArray class]] && [links count] > 0) linkItems_ = [links retain];
  if (reactions_) { [reactions_ release]; reactions_ = nil; }
  NSArray *rx = [dict objectForKey:@"reactions"];
  if ([rx isKindOfClass:[NSArray class]] && [rx count] > 0) reactions_ = [rx retain];
}

+ (CGFloat)cellHeightForMessageDict:(NSDictionary *)dict maxWidth:(CGFloat)maxWidth {
  NSNumber *cached = [dict objectForKey:@"_cachedHeight"];
  CGFloat h = cached ? [cached doubleValue] : EstimatedCellHeightForDict(dict, maxWidth);
  return h < 20.0 ? 44.0 : h;
}

static void DrawBubble(NSRect r, BOOL out) {
  CGFloat rad = 8.0;
  NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:r xRadius:rad yRadius:rad];
  if (out) [[NSColor colorWithCalibratedRed:0.58 green:0.72 blue:0.86 alpha:1.0] setFill];
  else [[NSColor colorWithCalibratedWhite:0.94 alpha:1.0] setFill];
  [p fill];
  if (out) [[NSColor colorWithCalibratedRed:0.45 green:0.60 blue:0.75 alpha:1.0] setStroke];
  else [[NSColor colorWithCalibratedWhite:0.78 alpha:1.0] setStroke];
  [p stroke];
}

static void MessageBubbleGeometryForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, CGFloat *cwOut, CGFloat *chOut, NSRect *bubbleOut, CGFloat *quoteHOut) {
  BOOL isOutgoing = [[dict objectForKey:@"isOutgoing"] boolValue];
  NSString *contentType = StringOrEmpty([dict objectForKey:@"contentType"]);
  NSString *messageText = StringOrEmpty([dict objectForKey:@"text"]);
  NSArray *reactions = [dict objectForKey:@"reactions"];
  NSString *webPageUrl = StringOrEmpty([dict objectForKey:@"webPageUrl"]);
  NSString *replyPreview = StringOrEmpty([dict objectForKey:@"replyPreview"]);
  CGFloat mbw = MessageBubbleMaxWidthForColumnWidth(maxWidth, isOutgoing);
  CGFloat cw = 0.0, ch = 0.0, diw = 0.0, dih = 0.0;
  BOOL hasImg = NO;

  if ([contentType isEqualToString:@"messagePhoto"] || [contentType isEqualToString:@"messageVideo"]) {
    long long pw = LongLongValue([dict objectForKey:@"imageWidth"]);
    long long ph = LongLongValue([dict objectForKey:@"imageHeight"]);
    BOOL wideMedia = ([messageText length] > 0 || [reactions count] > 0 || [webPageUrl length] > 0 || [contentType isEqualToString:@"messageVideo"]);
    if (pw > 0 && ph > 0) {
      NSSize ps = MediaPreviewSize(mbw - 16.0, pw, ph, contentType);
      diw = ps.width; dih = ps.height;
      cw = diw + 16.0; hasImg = YES;
    }
    if (!hasImg) cw = 190.0;
    if (wideMedia) cw = mbw;
    else {
      CGFloat mediaMinW = 240.0;
      if (mediaMinW > mbw) mediaMinW = mbw;
      if (cw < mediaMinW) cw = mediaMinW;
    }
    if (cw > mbw) cw = mbw;
    ch = hasImg ? (dih + 6.0) : 86.0;
    if ([messageText length] > 0) ch += 6.0 + TextHeightForWidthUncapped(messageText, [NSFont systemFontOfSize:12], cw - 16.0);
  } else if ([contentType isEqualToString:@"messageSticker"]) {
    cw = 120.0; ch = 80.0;
  } else {
    NSString *t = [messageText length] ? messageText : @" ";
    CGFloat tw = mbw - 16.0;
    CGFloat slw = [t sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:12] forKey:NSFontAttributeName]].width;
    if (slw < tw) tw = slw + 4.0;
    cw = tw + 16.0; if (cw < 40.0) cw = 40.0;
    BOOL isLong = [[dict objectForKey:@"isLongMessage"] boolValue];
    BOOL isExpanded = [[dict objectForKey:@"isExpanded"] boolValue];
    if (isLong && !isExpanded) ch = TextHeightForWidth(t, [NSFont systemFontOfSize:12], mbw - 16.0, 6) + 14.0;
    else ch = TextHeightForWidthUncapped(t, [NSFont systemFontOfSize:12], mbw - 16.0);
  }
  if (cw < 80.0) cw = 80.0; if (cw > mbw) cw = mbw;
  if (([replyPreview length] > 0 || [webPageUrl length] > 0) && cw < mbw) cw = mbw;

  CGFloat quoteH = 0.0;
  if ([replyPreview length] > 0) {
    quoteH = TextHeightForWidth(replyPreview, [NSFont systemFontOfSize:9], cw - 23.0, 2) + 4.0;
    if (quoteH < 18.0) quoteH = 18.0;
  }
  NSString *senderInitial = StringOrEmpty([dict objectForKey:@"senderInitial"]);
  CGFloat avatarOffset = (!isOutgoing && [senderInitial length] > 0) ? 34.0 : 0.0;
  CGFloat bx = isOutgoing ? cellFrame.origin.x + cellFrame.size.width - cw - 12.0 : cellFrame.origin.x + 12.0 + avatarOffset;
  CGFloat by = cellFrame.origin.y + 8.0;
  if (cwOut) *cwOut = cw;
  if (chOut) *chOut = ch;
  if (quoteHOut) *quoteHOut = quoteH;
  if (bubbleOut) *bubbleOut = NSMakeRect(bx, by, cw, 0.0);
}

BOOL MessageBodyTextRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut, NSString **displayTextOut) {
  NSString *contentType = StringOrEmpty([dict objectForKey:@"contentType"]);
  NSString *messageText = StringOrEmpty([dict objectForKey:@"text"]);
  if (![messageText length]) return NO;
  CGFloat cw = 0.0, ch = 0.0, quoteH = 0.0;
  NSRect br = NSZeroRect;
  MessageBubbleGeometryForDict(dict, cellFrame, maxWidth, &cw, &ch, &br, &quoteH);
  CGFloat cx = br.origin.x + 8.0;
  CGFloat cy = br.origin.y + 5.0 + 18.0 + quoteH;
  NSString *drawText = messageText;
  CGFloat bodyH = 0.0;
  if ([contentType isEqualToString:@"messagePhoto"] || [contentType isEqualToString:@"messageVideo"]) {
    long long pw = LongLongValue([dict objectForKey:@"imageWidth"]);
    long long ph = LongLongValue([dict objectForKey:@"imageHeight"]);
    if (pw <= 0 || ph <= 0) return NO;
    CGFloat mbw = MessageBubbleMaxWidthForColumnWidth(maxWidth, [[dict objectForKey:@"isOutgoing"] boolValue]);
    NSSize ps = MediaPreviewSize(mbw - 16.0, pw, ph, contentType);
    cy += ps.height + 4.0;
    bodyH = TextHeightForWidthUncapped(messageText, [NSFont systemFontOfSize:12], cw - 16.0);
  } else if (![contentType isEqualToString:@"messageSticker"]) {
    BOOL isLong = [[dict objectForKey:@"isLongMessage"] boolValue];
    BOOL isExpanded = [[dict objectForKey:@"isExpanded"] boolValue];
    if (isLong && !isExpanded) {
      drawText = TruncatedText(messageText, [NSFont systemFontOfSize:12], cw - 16.0, 6);
      bodyH = TextHeightForWidth(drawText, [NSFont systemFontOfSize:12], cw - 16.0, 6);
    } else {
      bodyH = TextHeightForWidthUncapped(messageText, [NSFont systemFontOfSize:12], cw - 16.0);
    }
  } else {
    return NO;
  }
  if (rectOut) *rectOut = NSMakeRect(cx, cy, cw - 16.0, bodyH);
  if (displayTextOut) *displayTextOut = drawText;
  return YES;
}

BOOL MessageMediaRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut) {
  NSString *contentType = StringOrEmpty([dict objectForKey:@"contentType"]);
  if (![contentType isEqualToString:@"messagePhoto"] && ![contentType isEqualToString:@"messageVideo"]) return NO;
  long long pw = LongLongValue([dict objectForKey:@"imageWidth"]);
  long long ph = LongLongValue([dict objectForKey:@"imageHeight"]);
  if (pw <= 0 || ph <= 0) return NO;
  CGFloat cw = 0.0, ch = 0.0, quoteH = 0.0;
  NSRect br = NSZeroRect;
  MessageBubbleGeometryForDict(dict, cellFrame, maxWidth, &cw, &ch, &br, &quoteH);
  NSSize ps = MediaPreviewSize(cw - 16.0, pw, ph, contentType);
  if (rectOut) *rectOut = NSMakeRect(br.origin.x + 8.0, br.origin.y + 5.0 + 18.0 + quoteH, ps.width, ps.height);
  return YES;
}

BOOL MessageWebPreviewRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut) {
  if (![StringOrEmpty([dict objectForKey:@"webPageUrl"]) length]) return NO;
  CGFloat cw = 0.0, ch = 0.0, quoteH = 0.0;
  NSRect br = NSZeroRect;
  MessageBubbleGeometryForDict(dict, cellFrame, maxWidth, &cw, &ch, &br, &quoteH);
  CGFloat cx = br.origin.x + 8.0;
  CGFloat y = br.origin.y + 5.0 + 18.0 + quoteH + ch + 8.0;
  NSString *site = StringOrEmpty([dict objectForKey:@"webPageSite"]);
  NSString *title = StringOrEmpty([dict objectForKey:@"webPageTitle"]);
  NSString *desc = StringOrEmpty([dict objectForKey:@"webPageDescription"]);
  BOOL hasPhoto = ([dict objectForKey:@"webPagePhotoPath"] != nil || [dict objectForKey:@"webPagePhotoId"] != nil);
  CGFloat h = WebPreviewCardHeight(cw - 16.0, hasPhoto, LongLongValue([dict objectForKey:@"webPagePhotoWidth"]), LongLongValue([dict objectForKey:@"webPagePhotoHeight"]), site, title, desc);
  if (rectOut) *rectOut = NSMakeRect(cx, y, cw - 16.0, h);
  return YES;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  (void)controlView;
  CGFloat mbw = MessageBubbleMaxWidthForColumnWidth(maxWidth_, isOutgoing_);
  CGFloat cw = 0, ch = 0;
  BOOL hasImg = NO;
  CGFloat diw = 0, dih = 0;

  if ([contentType_ isEqualToString:@"messagePhoto"] || [contentType_ isEqualToString:@"messageVideo"]) {
    long long pw = imageWidth_, ph = imageHeight_;
    NSString *cap = messageText_;
    BOOL wideMedia = ([cap length] > 0 || [reactions_ count] > 0 || webPageUrl_ != nil || [contentType_ isEqualToString:@"messageVideo"]);
    if (pw > 0 && ph > 0) {
      NSSize ps = MediaPreviewSize(mbw - 16.0, pw, ph, contentType_);
      diw = ps.width; dih = ps.height;
      cw = diw + 16.0; hasImg = YES;
    }
    if (!hasImg) cw = 190.0;
    if (wideMedia) {
      cw = mbw;
    } else {
      CGFloat mediaMinW = 240.0;
      if (mediaMinW > mbw) mediaMinW = mbw;
      if (cw < mediaMinW) cw = mediaMinW;
    }
    if (cw > mbw) cw = mbw;
    ch = hasImg ? (dih + 6.0) : 86.0;
    if ([cap length] > 0) ch += 6.0 + TextHeightForWidthUncapped(cap, [NSFont systemFontOfSize:12], cw - 16.0);
  } else if ([contentType_ isEqualToString:@"messageSticker"]) {
    cw = 120.0; ch = 80.0;
  } else {
    NSString *t = messageText_; if ([t length] == 0) t = @" ";
    CGFloat tw = mbw - 16.0;
    CGFloat slw = [t sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:12] forKey:NSFontAttributeName]].width;
    if (slw < tw) tw = slw + 4.0;
    cw = tw + 16.0; if (cw < 40.0) cw = 40.0;

    if (isLongMessage_ && !isExpanded_) {
      ch = TextHeightForWidth(t, [NSFont systemFontOfSize:12], mbw - 16.0, 6);
      ch += 14.0; // room for "Show more"
    } else {
      ch = TextHeightForWidthUncapped(t, [NSFont systemFontOfSize:12], mbw - 16.0);
    }
  }
  if (cw < 80.0) cw = 80.0; if (cw > mbw) cw = mbw;
  if ((replyPreview_ != nil || webPageUrl_ != nil) && cw < mbw) cw = mbw;

  // Avatar handling — left side for received messages
  CGFloat avatarSize = 28.0;
  CGFloat avatarPadding = 6.0;
  BOOL showAvatar = !isOutgoing_ && [senderInitial_ length] > 0;
  CGFloat avatarOffset = showAvatar ? avatarSize + avatarPadding : 0.0;

  CGFloat sndH = 18.0, tmeH = 14.0;
  CGFloat quoteH = 0.0;
  if (replyPreview_ != nil) {
    quoteH = TextHeightForWidth(replyPreview_, [NSFont systemFontOfSize:9], cw - 23.0, 2) + 4.0;
    if (quoteH < 18.0) quoteH = 18.0;
  }
  // Web page preview card height
  CGFloat webPageH = 0;
  if (webPageUrl_ != nil) {
    webPageH = 8.0 + WebPreviewCardHeight(cw - 16.0, webPageHasPhoto_, webPagePhotoWidth_, webPagePhotoHeight_, webPageSite_, webPageTitle_, webPageDescription_);
  }
  CGFloat reactionH = ReactionBadgesHeight(reactions_, cw - 16.0);
  CGFloat bh = sndH + quoteH + ch + webPageH + reactionH + tmeH + 14.0;
  CGFloat bx;
  if (isOutgoing_) {
    bx = cellFrame.origin.x + cellFrame.size.width - cw - 12.0;
  } else {
    bx = cellFrame.origin.x + 12.0 + avatarOffset;
  }
  CGFloat by = cellFrame.origin.y + 8.0;
  NSRect br = NSMakeRect(bx, by, cw, bh);
  DrawBubble(br, isOutgoing_);

  // Draw avatar for received messages
  if (showAvatar) {
    CGFloat avx = cellFrame.origin.x + 8.0;
    CGFloat avy = cellFrame.origin.y + 6.0;
    NSRect avr = NSMakeRect(avx, avy, avatarSize, avatarSize);
    // Clip to circle
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:avr];
    [NSGraphicsContext saveGraphicsState];
    [circle addClip];

    NSImage *avImg = senderAvatarPath_ ? ScaledCachedImageAtPath(senderAvatarPath_, avatarSize, avatarSize, YES) : nil;
    if (avImg) {
      [avImg drawAtPoint:NSMakePoint(avx, avy) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
    } else {
      // Colored circle with initial
      NSUInteger hash = [senderName_ hash];
      CGFloat hue = (CGFloat)(hash % 360) / 360.0;
      [[NSColor colorWithCalibratedHue:hue saturation:0.5 brightness:0.75 alpha:1.0] setFill];
      [circle fill];
      NSDictionary *initAttrs = [NSDictionary dictionaryWithObjectsAndKeys:
          [NSFont boldSystemFontOfSize:12], NSFontAttributeName,
          [NSColor whiteColor], NSForegroundColorAttributeName, nil];
      NSSize isz = [senderInitial_ sizeWithAttributes:initAttrs];
      [senderInitial_ drawAtPoint:NSMakePoint(avx + (avatarSize - isz.width) / 2.0, avy + (avatarSize - isz.height) / 2.0) withAttributes:initAttrs];
    }
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.75] setStroke];
    [circle setLineWidth:1.0];
    [circle stroke];
  }

  CGFloat cx = br.origin.x + 8.0, cy = br.origin.y + 5.0;
  NSColor *sc = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.8] : [NSColor colorWithCalibratedRed:0.2 green:0.45 blue:0.75 alpha:1.0];
  NSFont *senderFont = [NSFont boldSystemFontOfSize:10];
  NSDictionary *senderAttrs = [NSDictionary dictionaryWithObjectsAndKeys:senderFont, NSFontAttributeName, sc, NSForegroundColorAttributeName, nil];
  NSString *drawSender = TruncatedStringForWidth(senderName_, senderAttrs, cw - 16.0);
  DrawSingleLineEmojiText(drawSender, NSMakeRect(cx, cy, cw - 16.0, 14.0), sc, senderFont);
  cy += sndH;

  // Draw reply quote bar
  if (replyPreview_ != nil) {
    CGFloat quoteBarX = cx;
    CGFloat quoteBarW = 3.0;
    NSColor *qColor = [NSColor colorWithCalibratedRed:0.35 green:0.70 blue:0.92 alpha:1.0];
    [qColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(quoteBarX, cy - 1.0, quoteBarW, quoteH - 2.0) xRadius:1.5 yRadius:1.5] fill];
    NSColor *qtc = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.65] : [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
    NSMutableParagraphStyle *qstyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [qstyle setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *qattrs = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSFont systemFontOfSize:9], NSFontAttributeName,
      qtc, NSForegroundColorAttributeName,
      qstyle, NSParagraphStyleAttributeName,
      nil];
    [replyPreview_ drawInRect:NSMakeRect(cx + 7.0, cy, cw - 23.0, quoteH) withAttributes:qattrs];
    cy += quoteH;
  }

  CGFloat contentY = cy;
  if (hasImg) {
    NSRect ir = NSMakeRect(cx, cy, diw, dih);
    NSImage *img = imagePath_ ? ScaledCachedImageAtPath(imagePath_, ir.size.width, ir.size.height, NO) : nil;
    if (img && !hideMediaThumbnail_) {
      DrawRoundedImage(img, ir, 5.0, isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.35] : [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
      // Play button overlay for videos
      if ([contentType_ isEqualToString:@"messageVideo"]) {
        CGFloat playSize = 32.0;
        NSRect playRect = NSMakeRect(ir.origin.x + (ir.size.width - playSize) / 2.0, ir.origin.y + (ir.size.height - playSize) / 2.0, playSize, playSize);
        [[NSColor colorWithCalibratedWhite:0 alpha:0.5] setFill];
        NSBezierPath *playBg = [NSBezierPath bezierPathWithOvalInRect:playRect];
        [playBg fill];
        [[NSColor whiteColor] setFill];
        CGFloat px = playRect.origin.x + playSize * 0.35;
        CGFloat py = playRect.origin.y + playSize * 0.25;
        NSBezierPath *tri = [NSBezierPath bezierPath];
        [tri moveToPoint:NSMakePoint(px, py)];
        [tri lineToPoint:NSMakePoint(px + playSize * 0.4, py + playSize * 0.25)];
        [tri lineToPoint:NSMakePoint(px, py + playSize * 0.5)];
        [tri closePath];
        [tri fill];
      }
    } else if (!hideMediaThumbnail_) {
      [[NSColor colorWithCalibratedWhite:0.7 alpha:1.0] setFill];
      [[NSBezierPath bezierPathWithRoundedRect:ir xRadius:4.0 yRadius:4.0] fill];
      StrokeRoundedBorder(ir, 4.0, isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.35] : [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
      NSString *lb = [contentType_ isEqualToString:@"messageVideo"] ? @"Video" : @"Photo";
      NSColor *pc = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.7] : [NSColor grayColor];
      [lb drawAtPoint:NSMakePoint(cx + 8.0, cy + dih * 0.4) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:12], NSFontAttributeName, pc, NSForegroundColorAttributeName, nil]];
    }
    cy += dih + 4.0;
    NSString *cap = messageText_;
    if ([cap length] > 0) {
      NSColor *tc = isOutgoing_ ? [NSColor whiteColor] : [NSColor blackColor];
      NSArray *capSegs = EmojiSegmentsFromText(cap);
      CGFloat capH = TextHeightForWidthUncapped(cap, [NSFont systemFontOfSize:12], cw - 16.0);
      NSRect capRect = NSMakeRect(cx, cy, cw - 16.0, capH);
      NSColor *lc = [NSColor colorWithCalibratedRed:0.03 green:0.24 blue:0.72 alpha:1.0];
      if ([capSegs count] == 1 && [[[capSegs objectAtIndex:0] objectForKey:@"type"] isEqualToString:@"text"]) {
        DrawTextWithLinks(cap, linkItems_, capRect, tc, lc, [NSFont systemFontOfSize:12]);
      } else {
        DrawEmojiText(capSegs, capRect, tc, [NSFont systemFontOfSize:12]);
      }
    }
  } else if ([contentType_ isEqualToString:@"messagePhoto"] || [contentType_ isEqualToString:@"messageVideo"]) {
    NSString *ph = [contentType_ isEqualToString:@"messageVideo"] ? @"[Video loading...]" : @"[Photo loading...]";
    NSColor *pc = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.6] : [NSColor grayColor];
    [ph drawAtPoint:NSMakePoint(cx, cy + 30.0) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:12], NSFontAttributeName, pc, NSForegroundColorAttributeName, nil]];
  } else if ([contentType_ isEqualToString:@"messageSticker"]) {
    NSString *st = @"[Sticker]";
    NSColor *pc = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.6] : [NSColor grayColor];
    [st drawAtPoint:NSMakePoint(cx, cy + 30.0) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:12], NSFontAttributeName, pc, NSForegroundColorAttributeName, nil]];
  } else {
    NSColor *tc = isOutgoing_ ? [NSColor whiteColor] : [NSColor blackColor];
    if (isLongMessage_ && !isExpanded_) {
      NSString *displayText = TruncatedText(messageText_, [NSFont systemFontOfSize:12], cw - 16.0, 6);
      NSArray *txtSegs = EmojiSegmentsFromText(displayText);
      CGFloat bodyH = TextHeightForWidth(displayText, [NSFont systemFontOfSize:12], cw - 16.0, 6);
      NSRect bodyRect = NSMakeRect(cx, cy, cw - 16.0, bodyH);
      NSColor *lc = [NSColor colorWithCalibratedRed:0.03 green:0.24 blue:0.72 alpha:1.0];
      if ([txtSegs count] == 1 && [[[txtSegs objectAtIndex:0] objectForKey:@"type"] isEqualToString:@"text"]) {
        DrawTextWithLinks(displayText, linkItems_, bodyRect, tc, lc, [NSFont systemFontOfSize:12]);
      } else {
        DrawEmojiText(txtSegs, bodyRect, tc, [NSFont systemFontOfSize:12]);
      }
      CGFloat shY = cy + TextHeightForWidth(displayText, [NSFont systemFontOfSize:12], cw - 16.0, 6) + 2.0;
      NSColor *moreColor = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.6] : [NSColor colorWithCalibratedRed:0.35 green:0.70 blue:0.92 alpha:1.0];
      [@"Show more" drawAtPoint:NSMakePoint(cx, shY) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
          [NSFont boldSystemFontOfSize:10], NSFontAttributeName, moreColor, NSForegroundColorAttributeName, nil]];
    } else {
      NSArray *txtSegs = EmojiSegmentsFromText(messageText_);
      CGFloat bodyH = TextHeightForWidthUncapped(messageText_, [NSFont systemFontOfSize:12], cw - 16.0);
      NSRect bodyRect = NSMakeRect(cx, cy, cw - 16.0, bodyH);
      NSColor *lc = [NSColor colorWithCalibratedRed:0.03 green:0.24 blue:0.72 alpha:1.0];
      if ([txtSegs count] == 1 && [[[txtSegs objectAtIndex:0] objectForKey:@"type"] isEqualToString:@"text"]) {
        DrawTextWithLinks(messageText_, linkItems_, bodyRect, tc, lc, [NSFont systemFontOfSize:12]);
      } else {
        DrawEmojiText(txtSegs, bodyRect, tc, [NSFont systemFontOfSize:12]);
      }
    }
  }
  cy = contentY + ch;

  // Draw web page preview card
  if (webPageUrl_ != nil) {
    cy += 8.0;
    CGFloat cardW = cw - 16.0;
    CGFloat cardH = WebPreviewCardHeight(cardW, webPageHasPhoto_, webPagePhotoWidth_, webPagePhotoHeight_, webPageSite_, webPageTitle_, webPageDescription_);
    NSRect cardRect = NSMakeRect(cx, cy, cardW, cardH);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:6.0 yRadius:6.0];
    if (isOutgoing_) [[NSColor colorWithCalibratedWhite:1.0 alpha:0.34] setFill];
    else [[NSColor colorWithCalibratedWhite:0.985 alpha:1.0] setFill];
    [cardPath fill];
    [[NSColor colorWithCalibratedWhite:(isOutgoing_ ? 1.0 : 0.80) alpha:(isOutgoing_ ? 0.32 : 1.0)] setStroke];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];

    CGFloat cardPad = 8.0;
    CGFloat innerX = cardRect.origin.x + cardPad;
    CGFloat innerY = cardRect.origin.y + cardPad;
    CGFloat innerW = cardRect.size.width - cardPad * 2.0;
    if (innerW < 24.0) innerW = cardRect.size.width;

    if ([webPageSite_ length] > 0) {
      NSColor *siteColor = [NSColor colorWithCalibratedRed:0.30 green:0.40 blue:0.52 alpha:1.0];
      NSDictionary *siteAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:9], NSFontAttributeName, siteColor, NSForegroundColorAttributeName, nil];
      NSString *drawSite = TruncatedStringForWidth(webPageSite_, siteAttrs, innerW);
      [drawSite drawAtPoint:NSMakePoint(innerX, innerY) withAttributes:siteAttrs];
      innerY += 17.0;
    }

    if (webPageHasPhoto_) {
      NSSize previewSize = WebPreviewImageSize(innerW, webPagePhotoWidth_, webPagePhotoHeight_);
      CGFloat previewW = previewSize.width;
      CGFloat previewH = previewSize.height;
      NSImage *previewImg = ScaledCachedImageAtPath(webPagePhotoPath_, previewW, previewH, NO);
      NSRect pr = NSMakeRect(innerX, innerY, previewW, previewH);
      if (previewImg) {
        DrawRoundedImage(previewImg, pr, 5.0, isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.35] : [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
      } else {
        [[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:pr xRadius:5.0 yRadius:5.0] fill];
        StrokeRoundedBorder(pr, 5.0, isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.35] : [NSColor colorWithCalibratedWhite:0.70 alpha:1.0]);
      }
      innerY += previewH + 7.0;
    }

    if ([webPageTitle_ length] > 0) {
      NSColor *titleColor = [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
      NSMutableParagraphStyle *titleStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
      [titleStyle setLineBreakMode:NSLineBreakByWordWrapping];
      NSDictionary *titleAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:11], NSFontAttributeName, titleColor, NSForegroundColorAttributeName, titleStyle, NSParagraphStyleAttributeName, nil];
      CGFloat titleH = WebPreviewTextHeight(webPageTitle_, [NSFont boldSystemFontOfSize:11], innerW, 2);
      [webPageTitle_ drawInRect:NSMakeRect(innerX, innerY, innerW, titleH) withAttributes:titleAttrs];
      innerY += titleH + 4.0;
    }

    if ([webPageDescription_ length] > 0) {
      NSString *descText = NormalizePreviewDescription(webPageDescription_);
      NSColor *descColor = [NSColor colorWithCalibratedWhite:0.34 alpha:1.0];
      NSMutableParagraphStyle *descStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
      [descStyle setLineBreakMode:NSLineBreakByWordWrapping];
      NSDictionary *descAttrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:10], NSFontAttributeName, descColor, NSForegroundColorAttributeName, descStyle, NSParagraphStyleAttributeName, nil];
      CGFloat descH = WebPreviewTextHeight(descText, [NSFont systemFontOfSize:10], innerW, 4);
      [descText drawInRect:NSMakeRect(innerX, innerY, innerW, descH) withAttributes:descAttrs];
      innerY += descH;
    }
    cy += cardH;
  }

  // Draw reaction badges (positioned relative to content flow, not bubble)
  if (reactions_ != nil) {
    cy += 4.0;
    CGFloat rxX = cx;
    CGFloat rxY = cy;
    CGFloat rxMaxX = cx + cw - 16.0;
    CGFloat rxEmojiSize = 14.0;
    NSFont *rxCountFont = [NSFont systemFontOfSize:10];
    for (NSUInteger i = 0; i < [reactions_ count]; i++) {
      NSDictionary *rx = [reactions_ objectAtIndex:i];
      NSString *emoji = StringOrEmpty([rx objectForKey:@"emoji"]);
      int count = [[rx objectForKey:@"count"] intValue];
      BOOL chosen = [[rx objectForKey:@"chosen"] boolValue];

      NSArray *segs = EmojiSegmentsFromText(emoji);
      NSDictionary *emojiSeg = nil;
      if ([segs count] > 0) {
        NSDictionary *seg = [segs objectAtIndex:0];
        if ([[seg objectForKey:@"type"] isEqualToString:@"emoji"]) {
          emojiSeg = seg;
        }
      }

      NSString *countStr = [NSString stringWithFormat:@" %d", count];
      NSSize cs = [countStr sizeWithAttributes:[NSDictionary dictionaryWithObject:rxCountFont forKey:NSFontAttributeName]];
      CGFloat bw = rxEmojiSize + cs.width + 10.0;
      CGFloat bh2 = 20.0;
      if (rxX > cx && rxX + bw > rxMaxX) {
        rxX = cx;
        rxY += 22.0;
      }
      NSRect rxRect = NSMakeRect(rxX, rxY, bw, bh2);
      NSBezierPath *rxPath = [NSBezierPath bezierPathWithRoundedRect:rxRect xRadius:10.0 yRadius:10.0];
      if (chosen) {
        [[NSColor colorWithCalibratedRed:0.35 green:0.70 blue:0.92 alpha:0.3] setFill];
      } else {
        [[NSColor colorWithCalibratedWhite:0.85 alpha:1.0] setFill];
      }
      [rxPath fill];

      NSColor *rxc = chosen ? [NSColor colorWithCalibratedRed:0.2 green:0.45 blue:0.75 alpha:1.0] : [NSColor grayColor];

      // Draw twemoji image for reaction
      NSImage *rxImg = emojiSeg ? TwemojiImageForSegment(emojiSeg) : nil;
      if (rxImg) {
        NSRect er = NSMakeRect(rxX + 3.0, rxY + 3.0, rxEmojiSize, rxEmojiSize);
        [NSGraphicsContext saveGraphicsState];
        NSAffineTransform *flip = [NSAffineTransform transform];
        [flip translateXBy:NSMinX(er) yBy:NSMaxY(er)];
        [flip scaleXBy:1.0 yBy:-1.0];
        [flip concat];
        [rxImg drawInRect:NSMakeRect(0, 0, rxEmojiSize, rxEmojiSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
      } else {
        DrawMissingEmojiGlyph(NSMakeRect(rxX + 3.0, rxY + 3.0, rxEmojiSize, rxEmojiSize), rxc);
      }

      // Draw count
      [countStr drawAtPoint:NSMakePoint(rxX + rxEmojiSize + 5.0, rxY + 2.0) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:rxCountFont, NSFontAttributeName, rxc, NSForegroundColorAttributeName, nil]];
      rxX += bw + 4.0;
    }
    cy += ReactionBadgesHeight(reactions_, cw - 16.0);
  }

  NSFont *timeFont = [NSFont systemFontOfSize:9];
  NSDictionary *timeAttrs = [NSDictionary dictionaryWithObjectsAndKeys:timeFont, NSFontAttributeName, nil];
  CGFloat timeW = [timestampStr_ sizeWithAttributes:timeAttrs].width;
  CGFloat tx = br.origin.x + br.size.width - timeW - 8.0;
  CGFloat ty = br.origin.y + br.size.height - 15.0;
  NSColor *tc2 = isOutgoing_ ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.65] : [NSColor colorWithCalibratedWhite:0.5 alpha:1.0];
  [timestampStr_ drawAtPoint:NSMakePoint(tx, ty) withAttributes:[NSDictionary dictionaryWithObjectsAndKeys:timeFont, NSFontAttributeName, tc2, NSForegroundColorAttributeName, nil]];
}

@end
