#import "AppDelegatePrivate.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MediaViews.h"
#import "MessageCell.h"
#import "MessageContent.h"
#import "TelegramBridge.h"
#import "VideoPlayerView.h"

@implementation AppDelegate (Media)

- (NSString *)videoPathForMessage:(NSDictionary *)message requestDownload:(BOOL)request {
  if (![ContentTypeForMessage(message) isEqualToString:@"messageVideo"]) return nil;
  NSDictionary *content = [message objectForKey:@"content"];
  NSDictionary *video = [content objectForKey:@"video"];
  if (![video isKindOfClass:[NSDictionary class]]) return nil;
  NSDictionary *vfile = [video objectForKey:@"video"];
  if (![vfile isKindOfClass:[NSDictionary class]]) return nil;

  NSDictionary *local = [vfile objectForKey:@"local"];
  NSString *path = StringOrEmpty([local objectForKey:@"path"]);
  BOOL complete = [[local objectForKey:@"is_downloading_completed"] boolValue];
  long long expectedSize = LongLongValue([vfile objectForKey:@"expected_size"]);
  if (!expectedSize) expectedSize = LongLongValue([vfile objectForKey:@"size"]);
  long long downloadedSize = LongLongValue([local objectForKey:@"downloaded_size"]);
  long long fid = LongLongValue([vfile objectForKey:@"id"]);
  if (![path length] && fid) {
    path = [filePaths_ objectForKey:[NSNumber numberWithLongLong:fid]];
    complete = [path length] > 0;
  }
  if ([path length] && (complete || downloadedSize > 0 || (expectedSize > 0 && downloadedSize >= expectedSize))) return path;

  if (request && fid) {
    NSNumber *fidk = [NSNumber numberWithLongLong:fid];
    if (![pendingDownloads_ containsObject:fidk]) {
      [pendingDownloads_ addObject:fidk];
      [bridge_ downloadFile:fid priority:32];
    }
    [self setStatusText:[NSString stringWithFormat:@"Downloading video... %lld/%lld bytes", downloadedSize, expectedSize]];
  }
  return nil;
}

- (void)stopInlineVideoPlayer {
  if (inlineVideoStopping_) return;
  inlineVideoStopping_ = YES;
  long long oldMessageId = requestedVideoMessageId_;
  if (inlineVideoControlTimer_) { [inlineVideoControlTimer_ invalidate]; [inlineVideoControlTimer_ release]; inlineVideoControlTimer_ = nil; }
  NSView *container = inlineVideoContainer_;
  VideoPlayerView *player = inlineVideoPlayer_;
  inlineVideoContainer_ = nil;
  inlineVideoPlayer_ = nil;
  inlineVideoPlayButton_ = nil;
  inlineVideoSlider_ = nil;
  inlineVideoTimeLabel_ = nil;
  inlineVideoUserPaused_ = NO;
  inlineVideoAutoPaused_ = NO;
  requestedVideoFileId_ = 0;
  requestedVideoMessageId_ = 0;
  if (player) [player stop];
  if (player) [player removeFromSuperview];
  if (container) [container removeFromSuperview];
  if (container) [container release];
  if (player) [player release];
  if (oldMessageId) {
    [messageCellCache_ removeAllObjects];
  }
  inlineVideoStopping_ = NO;
}

- (BOOL)isInlineVideoVisible {
  if (!inlineVideoContainer_ || !messageTable_ || !messageScrollView_) return NO;
  NSRect visible = [messageTable_ visibleRect];
  NSRect frame = [inlineVideoContainer_ frame];
  NSRect intersection = NSIntersectionRect(visible, frame);
  if (NSIsEmptyRect(intersection)) return NO;
  CGFloat visibleArea = intersection.size.width * intersection.size.height;
  CGFloat totalArea = frame.size.width * frame.size.height;
  return totalArea <= 0.0 ? NO : (visibleArea / totalArea) >= 0.15;
}

- (void)updateInlineVideoVisibility {
  if (inlineVideoStopping_) return;
  if (!inlineVideoPlayer_) return;
  BOOL visible = [self isInlineVideoVisible];
  if (!visible) {
    if (![inlineVideoPlayer_ isPaused]) {
      [inlineVideoPlayer_ setPaused:YES];
      inlineVideoAutoPaused_ = YES;
    }
    return;
  }
  if (inlineVideoAutoPaused_ && !inlineVideoUserPaused_) {
    [inlineVideoPlayer_ setPaused:NO];
  }
  inlineVideoAutoPaused_ = NO;
}

- (void)presentVideoAtPath:(NSString *)path row:(NSInteger)row message:(NSDictionary *)message {
  if (![path isKindOfClass:[NSString class]] || ![path length]) {
    [self setStatusText:@"Video is downloading..."];
    return;
  }
  if (![message isKindOfClass:[NSDictionary class]]) return;
  if (row < 0 || row >= [messageTable_ numberOfRows]) return;
  [self stopInlineVideoPlayer];

  CGFloat mw = [[[messageTable_ tableColumns] objectAtIndex:0] width];
  NSDictionary *d = [self cachedMessageCellDictForMessage:message maxWidth:mw];
  BOOL isOutgoing = [[d objectForKey:@"isOutgoing"] boolValue];
  NSString *senderInitial = StringOrEmpty([d objectForKey:@"senderInitial"]);
  NSString *replyPreview = StringOrEmpty([d objectForKey:@"replyPreview"]);
  long long imageW = LongLongValue([d objectForKey:@"imageWidth"]);
  long long imageH = LongLongValue([d objectForKey:@"imageHeight"]);
  if (imageW <= 0 || imageH <= 0) { imageW = 320; imageH = 240; }

  CGFloat mbw = MessageBubbleMaxWidthForColumnWidth(mw, isOutgoing);
  NSSize mediaSize = MediaPreviewSize(mbw - 16.0, imageW, imageH, @"messageVideo");
  CGFloat mediaW = mediaSize.width;
  CGFloat mediaH = mediaSize.height;
  if (mediaW < 80.0) mediaW = 80.0;
  if (mediaH < 90.0) mediaH = 90.0;

  NSRect rowRect = [messageTable_ rectOfRow:row];
  CGFloat cw = mbw;
  CGFloat avatarOffset = (!isOutgoing && [senderInitial length] > 0) ? 34.0 : 0.0;
  CGFloat bx = isOutgoing ? rowRect.origin.x + rowRect.size.width - cw - 12.0 : rowRect.origin.x + 12.0 + avatarOffset;
  CGFloat by = rowRect.origin.y + 8.0;
  CGFloat cy = by + 2.0 + 16.0;
  if ([replyPreview length] > 0) {
    CGFloat qh = TextHeightForWidth(replyPreview, [NSFont systemFontOfSize:9], cw - 23.0, 2) + 4.0;
    cy += qh < 18.0 ? 18.0 : qh;
  }
  NSRect frame = NSMakeRect(bx + 8.0, cy, mediaW, mediaH);
  CGFloat controlsH = 24.0;
  NSString *thumbnailPath = StringOrEmpty([d objectForKey:@"imagePath"]);
  NSView *container = [[MediaFrameView alloc] initWithFrame:frame thumbnailPath:thumbnailPath controlsHeight:controlsH];
  CGFloat playerW = mediaW - 2.0;
  CGFloat playerH = mediaH - controlsH - 1.0;
  if (playerW < 10.0) playerW = mediaW;
  if (playerH < 20.0) playerH = mediaH - controlsH;
  VideoPlayerView *player = [[VideoPlayerView alloc] initWithFrame:NSMakeRect(1.0, controlsH, playerW, playerH) path:path];
  if (player) {
    long long mid = LongLongValue([message objectForKey:@"id"]);
    if (mid) requestedVideoMessageId_ = mid;
    inlineVideoContainer_ = container;
    inlineVideoPlayer_ = player;
    if ([thumbnailPath length] > 0) [inlineVideoPlayer_ setHidden:YES];
    [messageCellCache_ removeAllObjects];
    [messageTable_ reloadData];
    [inlineVideoContainer_ addSubview:inlineVideoPlayer_];

    inlineVideoPlayButton_ = [[PlaybackButtonView alloc] initWithFrame:NSMakeRect(4, 3, 28, 19)];
    SetPlaybackButtonIcon(inlineVideoPlayButton_, NO);
    [inlineVideoPlayButton_ setTarget:self];
    [inlineVideoPlayButton_ setAction:@selector(inlineVideoTogglePlay:)];
    [inlineVideoContainer_ addSubview:inlineVideoPlayButton_];
    [inlineVideoPlayButton_ release];

    CGFloat sliderW = mediaW - 110.0;
    if (sliderW < 40.0) sliderW = 40.0;
    inlineVideoSlider_ = [[NSSlider alloc] initWithFrame:NSMakeRect(36, 3, sliderW, 19)];
    [inlineVideoSlider_ setMinValue:0.0];
    [inlineVideoSlider_ setMaxValue:([inlineVideoPlayer_ durationSeconds] > 0.0 ? [inlineVideoPlayer_ durationSeconds] : 1.0)];
    [inlineVideoSlider_ setTarget:self];
    [inlineVideoSlider_ setAction:@selector(inlineVideoSliderChanged:)];
    [inlineVideoContainer_ addSubview:inlineVideoSlider_];
    [inlineVideoSlider_ release];

    inlineVideoTimeLabel_ = [[NSTextField alloc] initWithFrame:NSMakeRect(mediaW - 70, 5, 66, 15)];
    [inlineVideoTimeLabel_ setBezeled:NO]; [inlineVideoTimeLabel_ setDrawsBackground:NO];
    [inlineVideoTimeLabel_ setEditable:NO]; [inlineVideoTimeLabel_ setSelectable:NO];
    [inlineVideoTimeLabel_ setAlignment:NSRightTextAlignment];
    [inlineVideoTimeLabel_ setFont:[NSFont systemFontOfSize:9]];
    [inlineVideoTimeLabel_ setStringValue:@"0:00"];
    [inlineVideoContainer_ addSubview:inlineVideoTimeLabel_];
    [inlineVideoTimeLabel_ release];

    [messageTable_ addSubview:inlineVideoContainer_ positioned:NSWindowAbove relativeTo:nil];
    [player setNeedsDisplay:YES];
    inlineVideoUserPaused_ = NO;
    inlineVideoAutoPaused_ = NO;
    [self updateInlineVideoVisibility];
    inlineVideoControlTimer_ = [[NSTimer scheduledTimerWithTimeInterval:0.033 target:self selector:@selector(inlineVideoControlTimer:) userInfo:nil repeats:YES] retain];
  } else {
    if (container) [container release];
    [self setStatusText:@"Failed to open video file."];
  }
}

- (void)showImagePreviewOverlayAtPath:(NSString *)path {
  if (![path isKindOfClass:[NSString class]] || ![path length] || !mainWindow_) return;
  NSImage *image = CachedImageAtPath(path);
  if (!image) {
    [self setStatusText:@"Image is still downloading..."];
    return;
  }
  [self stopInlineVideoPlayer];
  NSView *overlayHost = [mainWindow_ contentView];
  if (!overlayHost) return;
  NSArray *subviews = [[overlayHost subviews] copy];
  for (NSUInteger i = 0; i < [subviews count]; i++) {
    NSView *view = [subviews objectAtIndex:i];
    if ([view isKindOfClass:[ImagePreviewOverlayView class]]) [view removeFromSuperview];
  }
  [subviews release];
  ImagePreviewOverlayView *overlay = [[ImagePreviewOverlayView alloc] initWithFrame:[overlayHost bounds] image:image];
  [overlay setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [overlayHost addSubview:overlay positioned:NSWindowAbove relativeTo:nil];
  [overlay release];
}

static NSString *PlaybackTimeString(double seconds) {
  if (seconds < 0.0) seconds = 0.0;
  int total = (int)floor(seconds + 0.5);
  int m = total / 60;
  int s = total % 60;
  return [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (IBAction)inlineVideoTogglePlay:(id)sender {
  (void)sender;
  if (inlineVideoStopping_) return;
  if (!inlineVideoPlayer_) return;
  BOOL pause = ![inlineVideoPlayer_ isPaused];
  inlineVideoUserPaused_ = pause;
  inlineVideoAutoPaused_ = NO;
  [inlineVideoPlayer_ setPaused:pause];
  SetPlaybackButtonIcon(inlineVideoPlayButton_, pause);
}

- (IBAction)inlineVideoSliderChanged:(id)sender {
  (void)sender;
  if (inlineVideoStopping_) return;
  if (!inlineVideoPlayer_ || !inlineVideoSlider_) return;
  inlineVideoUserPaused_ = NO;
  inlineVideoAutoPaused_ = NO;
  [inlineVideoPlayer_ seekToSeconds:[inlineVideoSlider_ doubleValue]];
  SetPlaybackButtonIcon(inlineVideoPlayButton_, NO);
}

- (void)inlineVideoControlTimer:(NSTimer *)timer {
  (void)timer;
  if (inlineVideoStopping_) return;
  if (!inlineVideoPlayer_) return;
  [self updateInlineVideoVisibility];
  if (![self isInlineVideoVisible]) return;
  if ([inlineVideoPlayer_ isHidden] && [inlineVideoPlayer_ hasDecodedFrame]) {
    [inlineVideoPlayer_ setHidden:NO];
    [inlineVideoContainer_ setNeedsDisplay:YES];
  }
  if ([inlineVideoPlayer_ hasPendingFrame]) [inlineVideoPlayer_ setNeedsDisplay:YES];
  double duration = [inlineVideoPlayer_ durationSeconds];
  double now = [inlineVideoPlayer_ currentTimeSeconds];
  if (inlineVideoSlider_) {
    [inlineVideoSlider_ setMaxValue:(duration > 0.0 ? duration : 1.0)];
    if (![[inlineVideoSlider_ cell] isHighlighted]) [inlineVideoSlider_ setDoubleValue:now];
  }
  SetPlaybackButtonIcon(inlineVideoPlayButton_, [inlineVideoPlayer_ isPaused]);
  if (inlineVideoTimeLabel_) {
    NSString *label = duration > 0.0 ? [NSString stringWithFormat:@"%@ / %@", PlaybackTimeString(now), PlaybackTimeString(duration)] : PlaybackTimeString(now);
    [inlineVideoTimeLabel_ setStringValue:label];
  }
}

- (void)playVideoAction:(NSMenuItem *)item {
  id rep = [item representedObject];
  NSString *path = nil;
  if ([rep isKindOfClass:[NSString class]]) path = rep;
  else if ([rep isKindOfClass:[NSDictionary class]]) path = [self videoPathForMessage:rep requestDownload:YES];
  NSInteger row = [messageTable_ selectedRow];
  NSDictionary *msg = [rep isKindOfClass:[NSDictionary class]] ? rep : nil;
  if (!msg && row >= 0) {
    NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
    NSArray *ms = [messagesByChatId_ objectForKey:cid];
      if (ms && (NSUInteger)row < [ms count]) msg = [ms objectAtIndex:(NSUInteger)row];
  }
  if ([msg isKindOfClass:[NSDictionary class]]) {
    requestedVideoMessageId_ = LongLongValue([msg objectForKey:@"id"]);
    requestedVideoFileId_ = VideoFileId([msg objectForKey:@"content"]);
  }
  [self presentVideoAtPath:path row:row message:msg];
}

@end
