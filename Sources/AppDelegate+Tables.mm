#import "AppDelegatePrivate.h"
#import "ChatCell.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MediaViews.h"
#import "MessageCell.h"
#import "MessageContent.h"
#import "TelegramBridge.h"
#import "VideoPlayerView.h"

@implementation AppDelegate (Tables)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  if (tv == chatTable_) return [chatIds_ count];
  NSArray *ms = [messagesByChatId_ objectForKey:[NSNumber numberWithLongLong:selectedChatId_]];
  return ms ? [ms count] : 0;
}

- (NSDictionary *)messageCellDictForMessage:(NSDictionary *)msg maxWidth:(CGFloat)mw {
  long long suid = 0;
  NSDictionary *sid = [msg objectForKey:@"sender_id"];
  if ([sid isKindOfClass:[NSDictionary class]]) suid = LongLongValue([sid objectForKey:@"user_id"]);
  BOOL isOut = (suid != 0 && meUserId_ != 0 && suid == meUserId_);
  NSString *sn = [self userNameForSender:sid];
  NSString *txt = PreviewTextForMessage(msg);
  NSString *ts = [self formatTimestamp:LongLongValue([msg objectForKey:@"date"])];
  NSString *ct = ContentTypeForMessage(msg);
  NSDictionary *content = [msg objectForKey:@"content"];
  NSString *ip = nil;
  long long iw = 0, ih = 0;
  NSNumber *fid = nil;

  if ([ct isEqualToString:@"messagePhoto"]) {
    ip = PhotoLocalPathFromContent(content);
    if (![ip length]) {
      NSNumber *pfid = PhotoFileIdFromContent(content);
      if (pfid) {
        NSString *cp = [filePaths_ objectForKey:pfid];
        if ([cp length]) ip = cp;
        if (![ip length]) fid = pfid;
      }
    }
    iw = PhotoWidthForContent(content); ih = PhotoHeightForContent(content);
    if (ip && (!iw || !ih)) { iw = 320; ih = 320; }
  } else if ([ct isEqualToString:@"messageVideo"]) {
    ip = VideoThumbnailLocalPath(content);
    if (![ip length]) {
      long long tid = VideoThumbnailFileId(content);
      if (tid) {
        NSString *cp = [filePaths_ objectForKey:[NSNumber numberWithLongLong:tid]];
        if ([cp length]) ip = cp;
        if (![ip length]) fid = [NSNumber numberWithLongLong:tid];
      }
    }
    // Get video dimensions
    NSDictionary *video = [content objectForKey:@"video"];
    if ([video isKindOfClass:[NSDictionary class]]) {
      iw = LongLongValue([video objectForKey:@"width"]);
      ih = LongLongValue([video objectForKey:@"height"]);
    }
    if (!iw || !ih) { iw = 320; ih = 240; }
  }

  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [d setObject:sn forKey:@"senderName"]; [d setObject:(txt ? txt : @"") forKey:@"text"];
  [d setObject:[NSNumber numberWithBool:isOut] forKey:@"isOutgoing"];
  [d setObject:(ts ? ts : @"") forKey:@"timestamp"]; [d setObject:(ct ? ct : @"text") forKey:@"contentType"];
  [d setObject:[NSNumber numberWithDouble:mw] forKey:@"maxWidth"];
  if (ip) [d setObject:ip forKey:@"imagePath"];
  [d setObject:[NSNumber numberWithLongLong:iw] forKey:@"imageWidth"];
  [d setObject:[NSNumber numberWithLongLong:ih] forKey:@"imageHeight"];
  [d setObject:[NSNumber numberWithInt:(fid ? 1 : 0)] forKey:@"fileDownloadPriority"];
  if (fid) [d setObject:fid forKey:@"fileIdToDownload"];
  NSArray *linkItems = LinkItemsForMessageContent(content);
  if ([linkItems count] > 0) [d setObject:linkItems forKey:@"linkItems"];

  // Video file path for playback
  if ([ct isEqualToString:@"messageVideo"]) {
    NSDictionary *videoObj = [content objectForKey:@"video"];
    if ([videoObj isKindOfClass:[NSDictionary class]]) {
      NSDictionary *vf = [videoObj objectForKey:@"video"];
      if ([vf isKindOfClass:[NSDictionary class]]) {
        NSString *vp = StringOrEmpty([[vf objectForKey:@"local"] objectForKey:@"path"]);
        if ([vp length]) [d setObject:vp forKey:@"videoPath"];
        else {
          long long vfid = LongLongValue([vf objectForKey:@"id"]);
          NSString *cp = [filePaths_ objectForKey:[NSNumber numberWithLongLong:vfid]];
          if ([cp length]) [d setObject:cp forKey:@"videoPath"];
        }
      }
    }
  }

  // Sender avatar
  NSString *avPath = nil;
  NSString *avInit = @"";
  if (suid != 0) {
    NSDictionary *user = [usersById_ objectForKey:[NSNumber numberWithLongLong:suid]];
    if (user) {
      NSString *first = StringOrEmpty([user objectForKey:@"first_name"]);
      if ([first length]) avInit = [[first substringToIndex:1] uppercaseString];
      else avInit = @"?";
      // Check for profile photo
      NSDictionary *pp = [user objectForKey:@"profile_photo"];
      if ([pp isKindOfClass:[NSDictionary class]]) {
        // Check direct local path first (TDLib may have cached it)
        NSString *directPath = ProfilePhotoLocalPath(pp);
        if ([directPath length]) {
          avPath = directPath;
        } else {
          long long pfid = PhotoSmallFileIdFromPhotoDict(pp);
          if (pfid) {
            NSString *cached = [filePaths_ objectForKey:[NSNumber numberWithLongLong:pfid]];
            if ([cached length]) avPath = cached;
            else if (![pendingDownloads_ containsObject:[NSNumber numberWithLongLong:pfid]]) {
              [pendingDownloads_ addObject:[NSNumber numberWithLongLong:pfid]];
              [bridge_ downloadFile:pfid priority:8];
            }
          }
        }
      }
    }
  }
  if (avPath) [d setObject:avPath forKey:@"avatarPath"];
  [d setObject:avInit forKey:@"senderInitial"];

  // Reply/quote info
  NSDictionary *replyTo = [msg objectForKey:@"reply_to"];
  if ([replyTo isKindOfClass:[NSDictionary class]]) {
    long long replyMsgId = LongLongValue([replyTo objectForKey:@"message_id"]);
    if (replyMsgId) {
      [d setObject:[NSNumber numberWithLongLong:replyMsgId] forKey:@"replyToMessageId"];
      // Try to find the quoted message in cache
      NSNumber *cidKey = [NSNumber numberWithLongLong:selectedChatId_];
      NSArray *cached = [messagesByChatId_ objectForKey:cidKey];
      if (cached) {
        for (NSUInteger i = 0; i < [cached count]; i++) {
          NSDictionary *rm = [cached objectAtIndex:i];
          if (LongLongValue([rm objectForKey:@"id"]) == replyMsgId) {
            NSString *rsn = [self userNameForSender:[rm objectForKey:@"sender_id"]];
            NSString *rpt = PreviewTextForMessage(rm);
            if (![rpt length]) rpt = @"[Media]";
            [d setObject:[NSString stringWithFormat:@"%@: %@", rsn, rpt] forKey:@"replyPreview"];
            break;
          }
        }
      }
    }
  }

  // Show more for long text messages
  long long mid = LongLongValue([msg objectForKey:@"id"]);

  // Extract link preview from content (supports web_page or link_preview)
  if ([ct isEqualToString:@"messageText"]) {
    NSDictionary *webPage = [content objectForKey:@"web_page"];
    if (![webPage isKindOfClass:[NSDictionary class]]) webPage = [content objectForKey:@"link_preview"];
    if ([webPage isKindOfClass:[NSDictionary class]]) {
      NSString *wpUrl = StringOrEmpty([webPage objectForKey:@"url"]);
      NSString *wpTitle = StringOrEmpty([webPage objectForKey:@"title"]);
      NSString *wpDesc = NormalizePreviewDescription(TextFieldStringOrEmpty([webPage objectForKey:@"description"]));
      NSString *wpSite = StringOrEmpty([webPage objectForKey:@"site_name"]);
      NSString *wpDisplayUrl = StringOrEmpty([webPage objectForKey:@"display_url"]);
      if ([wpUrl length] > 0) {
        [d setObject:wpUrl forKey:@"webPageUrl"];
        if ([wpTitle length]) [d setObject:wpTitle forKey:@"webPageTitle"];
        else [d setObject:wpUrl forKey:@"webPageTitle"]; // fallback: show URL as title
        if ([wpDesc length]) [d setObject:wpDesc forKey:@"webPageDescription"];
        if ([wpSite length]) [d setObject:wpSite forKey:@"webPageSite"];
        else if ([wpDisplayUrl length]) [d setObject:wpDisplayUrl forKey:@"webPageSite"];
        if ([wpDisplayUrl length]) [d setObject:wpDisplayUrl forKey:@"webPageDisplayUrl"];
        NSString *ppath = nil;
        long long previewW = 0, previewH = 0;
        long long pfid = PreviewImageFileIdFromWebPageDict(webPage, &ppath, &previewW, &previewH);
        if (pfid) {
          NSNumber *pfidk = [NSNumber numberWithLongLong:pfid];
          [d setObject:pfidk forKey:@"webPagePhotoId"];
          if (previewW > 0) [d setObject:[NSNumber numberWithLongLong:previewW] forKey:@"webPagePhotoWidth"];
          if (previewH > 0) [d setObject:[NSNumber numberWithLongLong:previewH] forKey:@"webPagePhotoHeight"];
          if (![ppath length]) ppath = [filePaths_ objectForKey:pfidk];
          if ([ppath length]) [d setObject:ppath forKey:@"webPagePhotoPath"];
        }
      }
    }
  }

  BOOL isLong = NO;
  if ([ct isEqualToString:@"messageText"]) {
    CGFloat maxW = MessageBubbleMaxWidthForColumnWidth(mw, isOut) - 16.0;
    if (maxW > 0) isLong = (EstimatedLineCountForText(txt, [NSFont systemFontOfSize:12], maxW) > 6);
  }
  BOOL expanded = [expandedMessages_ containsObject:[NSNumber numberWithLongLong:mid]];
  [d setObject:[NSNumber numberWithBool:isLong] forKey:@"isLongMessage"];
  [d setObject:[NSNumber numberWithBool:expanded] forKey:@"isExpanded"];
  [d setObject:[NSNumber numberWithLongLong:mid] forKey:@"messageId"];
  if ([ct isEqualToString:@"messageVideo"] && inlineVideoContainer_ && mid == requestedVideoMessageId_) {
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"hideMediaThumbnail"];
  }

  // Reactions
  NSDictionary *interaction = [msg objectForKey:@"interaction_info"];
  if ([interaction isKindOfClass:[NSDictionary class]]) {
    NSDictionary *rxs = [interaction objectForKey:@"reactions"];
    if ([rxs isKindOfClass:[NSDictionary class]]) {
      NSArray *rxList = [rxs objectForKey:@"reactions"];
      if ([rxList isKindOfClass:[NSArray class]] && [rxList count] > 0) {
        NSMutableArray *rxData = [NSMutableArray array];
        for (NSUInteger i = 0; i < [rxList count]; i++) {
          NSDictionary *rx = [rxList objectAtIndex:i];
          if (![rx isKindOfClass:[NSDictionary class]]) continue;
          NSString *emoji = StringOrEmpty([[rx objectForKey:@"type"] objectForKey:@"emoji"]);
          int count = (int)LongLongValue([rx objectForKey:@"total_count"]);
          BOOL chosen = [[rx objectForKey:@"is_chosen"] boolValue];
          if ([emoji length] && count > 0) {
            [rxData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
              emoji, @"emoji", [NSNumber numberWithInt:count], @"count",
              [NSNumber numberWithBool:chosen], @"chosen", nil]];
          }
        }
        if ([rxData count] > 0) [d setObject:rxData forKey:@"reactions"];
      }
    }
  }

  // Precompute and cache the cell height
  [d setObject:[NSNumber numberWithDouble:EstimatedCellHeightForDict(d, mw)] forKey:@"_cachedHeight"];

  return d;
}

- (NSDictionary *)cachedMessageCellDictForMessage:(NSDictionary *)msg maxWidth:(CGFloat)mw {
  long long mid = LongLongValue([msg objectForKey:@"id"]);
  BOOL expanded = [expandedMessages_ containsObject:[NSNumber numberWithLongLong:mid]];
  long long widthKey = (long long)ceil(mw);
  NSString *key = [NSString stringWithFormat:@"%lld:%lld:%lld:%d", selectedChatId_, mid, widthKey, expanded ? 1 : 0];
  NSDictionary *cached = [messageCellCache_ objectForKey:key];
  if (cached) return cached;
  NSDictionary *d = [self messageCellDictForMessage:msg maxWidth:mw];
  if (d && key) [messageCellCache_ setObject:d forKey:key];
  return d;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)row {
  (void)tc;
  if (tv == chatTable_) {
    if (row < 0 || (NSUInteger)row >= [chatIds_ count]) return @"";
    NSNumber *cid = [chatIds_ objectAtIndex:(NSUInteger)row];
    NSDictionary *c = [chatsById_ objectForKey:cid];
    NSString *title = StringOrEmpty([c objectForKey:@"title"]);
    return [title length] ? title : @"Deleted Account";
  }
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  if (!ms || row < 0 || (NSUInteger)row >= [ms count]) return [NSDictionary dictionary];
  NSDictionary *msg = [ms objectAtIndex:(NSUInteger)row];
  return [self cachedMessageCellDictForMessage:msg maxWidth:[[[messageTable_ tableColumns] objectAtIndex:0] width]];
}

- (void)tableView:(NSTableView *)tv willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tc row:(NSInteger)row {
  (void)tc;
  if (tv == chatTable_) {
    if ([cell isKindOfClass:[ChatCell class]] && row >= 0 && (NSUInteger)row < [chatIds_ count]) {
      NSNumber *cid = [chatIds_ objectAtIndex:(NSUInteger)row];
      NSDictionary *chat = [chatsById_ objectForKey:cid];
      NSString *title = StringOrEmpty([chat objectForKey:@"title"]);
      if (![title length]) title = @"Deleted Account";
      NSString *preview = StringOrEmpty([chat objectForKey:@"preview"]);
      int unread = (int)LongLongValue([chat objectForKey:@"unread_count"]);
      NSString *avatarPath = nil;
      NSDictionary *chatPhoto = [chat objectForKey:@"photo"];
      if ([chatPhoto isKindOfClass:[NSDictionary class]]) {
        long long pfid = PhotoSmallFileIdFromPhotoDict(chatPhoto);
        if (pfid) avatarPath = [filePaths_ objectForKey:[NSNumber numberWithLongLong:pfid]];
        if (![avatarPath length]) avatarPath = ProfilePhotoLocalPath(chatPhoto);
        if (pfid && ![avatarPath length]) {
          NSNumber *fidk = [NSNumber numberWithLongLong:pfid];
          if (![pendingDownloads_ containsObject:fidk]) {
            [pendingDownloads_ addObject:fidk];
            [bridge_ downloadFile:pfid priority:10];
          }
        }
      }
      NSString *initial = @"?";
      if ([title length] > 0) {
        NSUInteger len = [title length];
        NSUInteger firstLen = 1;
        unichar first = [title characterAtIndex:0];
        if (first >= 0xD800 && first <= 0xDBFF && len > 1) firstLen = 2;
        initial = [[title substringToIndex:firstLen] uppercaseString];
      }
      [(ChatCell *)cell configureWithTitle:title preview:preview unread:unread avatarPath:avatarPath initial:initial];
    }
    return;
  }
  if ([cell isKindOfClass:[MessageCell class]]) {
    NSDictionary *d = [cell objectValue];
    if ([d isKindOfClass:[NSDictionary class]]) [(MessageCell *)cell configureWithMessageDict:d];
    NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
    NSArray *ms = [messagesByChatId_ objectForKey:cid];
    if (row >= 0 && (NSUInteger)row < [ms count]) [self requestFileDownloadForMessage:[ms objectAtIndex:(NSUInteger)row]];
  }
}

- (NSCell *)tableView:(NSTableView *)tv dataCellForTableColumn:(NSTableColumn *)tc row:(NSInteger)row {
  (void)tv; (void)row;
  return [tc dataCell];
}

- (CGFloat)tableView:(NSTableView *)tv heightOfRow:(NSInteger)row {
  if (tv == chatTable_) return 44.0;
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  if (row < 0 || (NSUInteger)row >= [ms count]) return 44.0;
  NSDictionary *msg = [ms objectAtIndex:(NSUInteger)row];
  CGFloat mw = [[[messageTable_ tableColumns] objectAtIndex:0] width];
  NSDictionary *d = [self cachedMessageCellDictForMessage:msg maxWidth:mw];
  CGFloat estimated = [MessageCell cellHeightForMessageDict:d maxWidth:mw];
  CGFloat guarded = ceil(estimated * 1.04) + 6.0;
  return guarded < 56.0 ? 56.0 : guarded;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note {
  if ([note object] != chatTable_) return;
  NSInteger row = [chatTable_ selectedRow];
  if (row < 0 || row >= (NSInteger)[chatIds_ count]) return;
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(openSelectedChatDeferred) object:nil];
  [self performSelector:@selector(openSelectedChatDeferred) withObject:nil afterDelay:0.0];
}

- (void)openSelectedChatDeferred {
  if (!chatTable_) return;
  NSInteger row = [chatTable_ selectedRow];
  if (row < 0 || row >= (NSInteger)[chatIds_ count]) return;
  if (inlineVideoContainer_) [self stopInlineVideoPlayer];
  NSNumber *cid = [chatIds_ objectAtIndex:(NSUInteger)row];
  selectedChatId_ = [cid longLongValue]; historyRetries_ = 0;
  [messageCellCache_ removeAllObjects];
  pendingMessageHeightInvalidation_ = YES;
  NSDictionary *c = [chatsById_ objectForKey:cid];
  [self setStatusText:[NSString stringWithFormat:@"Loading %@", StringOrEmpty([c objectForKey:@"title"])]];
  [bridge_ openChat:selectedChatId_];
  // A chat list's last_message can be stale while TDLib is synchronizing. Zero
  // explicitly requests the newest server-side history instead of anchoring the
  // result behind that stale message.
  [bridge_ loadChatHistory:selectedChatId_ fromMessageId:0];
  // Immediately clear unread badge for selected chat
  NSMutableDictionary *selChat = [chatsById_ objectForKey:cid];
  [selChat setObject:[NSNumber numberWithInt:0] forKey:@"unread_count"];
  [chatTable_ setNeedsDisplay:YES];
  // Show call button for private chats
  NSDictionary *selType = [c objectForKey:@"type"];
  BOOL isPrivate = [[selType objectForKey:@"@type"] isEqualToString:@"chatTypePrivate"];
  if (callButton_) [callButton_ setEnabled:isPrivate];
}

- (NSInteger)rowForMessageId:(long long)messageId {
  if (!messageId || !selectedChatId_) return -1;
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  for (NSUInteger i = 0; i < [ms count]; i++) {
    if (LongLongValue([[ms objectAtIndex:i] objectForKey:@"id"]) == messageId) return (NSInteger)i;
  }
  return -1;
}

@end
