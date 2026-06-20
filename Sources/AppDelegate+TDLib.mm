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

@implementation AppDelegate (TDLib)

- (NSString *)readableConnectionState:(NSString *)st {
  if ([st isEqualToString:@"connectionStateWaitingForNetwork"]) return @"Waiting for network...";
  if ([st isEqualToString:@"connectionStateConnecting"]) return @"Connecting...";
  if ([st isEqualToString:@"connectionStateConnectingToProxy"]) return @"Connecting to proxy...";
  if ([st isEqualToString:@"connectionStateUpdating"]) return @"Updating...";
  if ([st isEqualToString:@"connectionStateReady"]) return @"Connected.";
  return st;
}

- (NSString *)userNameForSender:(NSDictionary *)sid {
  NSString *tp = StringOrEmpty([sid objectForKey:@"@type"]);
  if ([tp isEqualToString:@"messageSenderUser"]) {
    long long uid = LongLongValue([sid objectForKey:@"user_id"]);
    NSDictionary *u = [usersById_ objectForKey:[NSNumber numberWithLongLong:uid]];
    if (u) {
      NSString *f = StringOrEmpty([u objectForKey:@"first_name"]);
      NSString *l = StringOrEmpty([u objectForKey:@"last_name"]);
      if ([f length] && [l length]) return [NSString stringWithFormat:@"%@ %@", f, l];
      if ([f length]) return f; if ([l length]) return l;
      NSString *un = StringOrEmpty([u objectForKey:@"username"]);
      if ([un length]) return [NSString stringWithFormat:@"@%@", un];
    }
    return [NSString stringWithFormat:@"User %lld", uid];
  }
  if ([tp isEqualToString:@"messageSenderChat"]) {
    long long cid = LongLongValue([sid objectForKey:@"chat_id"]);
    NSDictionary *chat = [chatsById_ objectForKey:[NSNumber numberWithLongLong:cid]];
    NSString *title = StringOrEmpty([chat objectForKey:@"title"]);
    if ([title length]) return title;
    if (cid == selectedChatId_) {
      NSDictionary *selectedChat = [chatsById_ objectForKey:[NSNumber numberWithLongLong:selectedChatId_]];
      title = StringOrEmpty([selectedChat objectForKey:@"title"]);
      if ([title length]) return title;
    }
    return cid ? [NSString stringWithFormat:@"Chat %lld", cid] : @"Chat";
  }
  return @"Unknown";
}

- (NSString *)formatTimestamp:(long long)ut {
  if (ut <= 0) return @"";
  time_t t = (time_t)ut;
  struct tm *ti = localtime(&t);
  if (!ti) return @"";
  struct tm msgTime = *ti;
  time_t now = time(NULL);
  struct tm *ni = localtime(&now);
  if (ni && ni->tm_year == msgTime.tm_year && ni->tm_yday == msgTime.tm_yday) {
    return [NSString stringWithFormat:@"%02d:%02d", msgTime.tm_hour, msgTime.tm_min];
  }
  char buf[32];
  const char *fmt = (ni && ni->tm_year == msgTime.tm_year) ? "%b %d" : "%b %d %Y";
  if (strftime(buf, sizeof(buf), fmt, &msgTime) == 0) return @"";
  return [NSString stringWithUTF8String:buf];
}

- (void)cacheUsersFromArray:(NSArray *)arr {
  if (![arr isKindOfClass:[NSArray class]]) return;
  for (NSUInteger i = 0; i < [arr count]; i++) {
    NSDictionary *u = [arr objectAtIndex:i];
    if (![u isKindOfClass:[NSDictionary class]]) continue;
    NSNumber *uid = [NSNumber numberWithLongLong:LongLongValue([u objectForKey:@"id"])];
    if (uid) [usersById_ setObject:u forKey:uid];
  }
}

- (void)upsertChat:(NSDictionary *)chat {
  NSNumber *cid = [chat objectForKey:@"id"]; if (!cid) return;
  NSMutableDictionary *mc = [NSMutableDictionary dictionaryWithDictionary:chat];
  NSDictionary *lm = [chat objectForKey:@"last_message"];
  if ([lm isKindOfClass:[NSDictionary class]]) [mc setObject:MessagePreviewFromContent([lm objectForKey:@"content"]) forKey:@"preview"];
  NSArray *pos = [chat objectForKey:@"positions"];
  if ([pos count] > 0) {
    NSString *order = [NSString stringWithFormat:@"%lld", LongLongValue([[pos objectAtIndex:0] objectForKey:@"order"])];
    [mc setObject:order forKey:@"order"];
  } else if (![mc objectForKey:@"order"]) { [mc setObject:@"0" forKey:@"order"]; }
  [mc setObject:[NSNumber numberWithLongLong:LongLongValue([chat objectForKey:@"unread_count"])] forKey:@"unread_count"];
  // Request chat photo download
  NSDictionary *chatPhoto = [chat objectForKey:@"photo"];
  if ([chatPhoto isKindOfClass:[NSDictionary class]]) {
    long long pfid = PhotoSmallFileIdFromPhotoDict(chatPhoto);
    if (pfid) {
      NSNumber *fidk = [NSNumber numberWithLongLong:pfid];
      NSString *localPath = ProfilePhotoLocalPath(chatPhoto);
      if ([localPath length]) [filePaths_ setObject:localPath forKey:fidk];
    }
  }
  [chatsById_ setObject:mc forKey:cid];
}

- (void)refreshChats {
  if (!chatTable_) return;
  [chatIds_ removeAllObjects];
  NSEnumerator *e = [chatsById_ keyEnumerator]; NSNumber *cid;
  while ((cid = [e nextObject])) {
    NSDictionary *chat = [chatsById_ objectForKey:cid];
    if ([chatFilter_ length] > 0) {
      NSString *hay = [NSString stringWithFormat:@"%@ %@", StringOrEmpty([chat objectForKey:@"title"]), StringOrEmpty([chat objectForKey:@"preview"])];
      if ([hay rangeOfString:chatFilter_ options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
    }
    [chatIds_ addObject:cid];
  }
  [chatIds_ sortUsingFunction:CompareChatIds context:chatsById_];
  [chatTable_ reloadData];
}

- (void)refreshMessages {
  if (!messageTable_) return;
  if (inlineVideoContainer_) [self stopInlineVideoPlayer];
  pendingMessageHeightInvalidation_ = YES;
  [self updateMainLayout];
  [messageTable_ reloadData];
  NSInteger rc = [messageTable_ numberOfRows];
  if (rc > 0) [messageTable_ scrollRowToVisible:(rc - 1)];
}

- (void)scheduleChatRefresh {
  if (chatRefreshScheduled_) return;
  chatRefreshScheduled_ = YES;
  [self performSelector:@selector(performScheduledChatRefresh) withObject:nil afterDelay:0.18];
}

- (void)scheduleMessageRefresh {
  if (messageRefreshScheduled_) return;
  messageRefreshScheduled_ = YES;
  [self performSelector:@selector(performScheduledMessageRefresh) withObject:nil afterDelay:0.18];
}

- (void)performScheduledChatRefresh {
  chatRefreshScheduled_ = NO;
  [self refreshChats];
}

- (void)performScheduledMessageRefresh {
  messageRefreshScheduled_ = NO;
  if (!messageTable_) return;
  pendingMessageHeightInvalidation_ = YES;
  [self updateMainLayout];
  [messageTable_ reloadData];
}

- (void)appendMessage:(NSDictionary *)msg toChatId:(NSNumber *)cid {
  if (!cid) return;
  NSMutableArray *ms = [messagesByChatId_ objectForKey:cid];
  if (!ms) { ms = [NSMutableArray array]; [messagesByChatId_ setObject:ms forKey:cid]; }
  [ms addObject:msg];
  [messageCellCache_ removeAllObjects];
  pendingMessageHeightInvalidation_ = YES;
}

- (void)replaceMessages:(NSArray *)msgs chatId:(NSNumber *)cid {
  if (!cid) return;
  NSMutableArray *mm = [NSMutableArray arrayWithArray:msgs];
  [mm sortUsingFunction:CompareMessagesById context:NULL];
  [messagesByChatId_ setObject:mm forKey:cid];
  [messageCellCache_ removeAllObjects];
  pendingMessageHeightInvalidation_ = YES;
}

- (void)requestFileDownloadForMessage:(NSDictionary *)message {
  NSDictionary *content = [message objectForKey:@"content"];
  NSString *ct = StringOrEmpty([content objectForKey:@"@type"]);
  if ([ct isEqualToString:@"messagePhoto"]) {
    NSNumber *fid = PhotoFileIdFromContent(content);
    if (!fid || [fid longLongValue] == 0) return;
    if ([filePaths_ objectForKey:fid]) return;
    NSString *lp = PhotoLocalPathFromContent(content);
    if ([lp length]) { [filePaths_ setObject:lp forKey:fid]; return; }
    if ([pendingDownloads_ containsObject:fid]) return;
    [pendingDownloads_ addObject:fid];
    [bridge_ downloadFile:[fid longLongValue] priority:16];
  } else if ([ct isEqualToString:@"messageVideo"]) {
    // Download thumbnail
    long long thumbId = VideoThumbnailFileId(content);
    if (thumbId) {
      NSNumber *fid = [NSNumber numberWithLongLong:thumbId];
      if (![filePaths_ objectForKey:fid] && ![pendingDownloads_ containsObject:fid]) {
        NSString *lp = VideoThumbnailLocalPath(content);
        if ([lp length]) { [filePaths_ setObject:lp forKey:fid]; }
        else { [pendingDownloads_ addObject:fid]; [bridge_ downloadFile:thumbId priority:16]; }
      }
    }
  } else if ([ct isEqualToString:@"messageText"]) {
    NSDictionary *webPage = [content objectForKey:@"web_page"];
    if (![webPage isKindOfClass:[NSDictionary class]]) webPage = [content objectForKey:@"link_preview"];
    if (![webPage isKindOfClass:[NSDictionary class]]) return;

    NSString *localPath = nil;
    long long previewId = PreviewImageFileIdFromWebPageDict(webPage, &localPath, NULL, NULL);

    if (!previewId) return;
    NSNumber *fid = [NSNumber numberWithLongLong:previewId];
    if ([filePaths_ objectForKey:fid]) return;
    if ([localPath length]) { [filePaths_ setObject:localPath forKey:fid]; return; }
    if ([pendingDownloads_ containsObject:fid]) return;
    [pendingDownloads_ addObject:fid];
    [bridge_ downloadFile:previewId priority:12];
  }
}

- (void)handleFileDictionary:(NSDictionary *)fd {
  if (![fd isKindOfClass:[NSDictionary class]]) return;
  NSDictionary *local = [fd objectForKey:@"local"];
  NSString *path = StringOrEmpty([local objectForKey:@"path"]);
  long long fid = LongLongValue([fd objectForKey:@"id"]);
  BOOL complete = [[local objectForKey:@"is_downloading_completed"] boolValue];
  long long expectedSize = LongLongValue([fd objectForKey:@"expected_size"]);
  if (!expectedSize) expectedSize = LongLongValue([fd objectForKey:@"size"]);
  long long downloadedSize = LongLongValue([local objectForKey:@"downloaded_size"]);
  if ([path length] > 0 && fid != 0 && (complete || (expectedSize > 0 && downloadedSize >= expectedSize))) {
    NSNumber *fidk = [NSNumber numberWithLongLong:fid];
    [filePaths_ setObject:path forKey:fidk];
    [pendingDownloads_ removeObject:fidk];
    if (fid == profilePhotoFileId_) {
      if (profilePhotoPath_) [profilePhotoPath_ release];
      profilePhotoPath_ = [path copy];
      [self updateProfilePhoto];
    }
    pendingMessageHeightInvalidation_ = YES;
    [self scheduleChatRefresh];
    if (selectedChatId_) [self scheduleMessageRefresh];
  }
}

- (BOOL)handleTDLibSessionObjectJSON:(const json *)objPtr type:(NSString *)type {
  if (!objPtr) return NO;
  const json &obj = *objPtr;

  if ([type isEqualToString:@"updateAuthorizationState"]) {
    NSString *st = @"";
    if (obj.contains("authorization_state") && obj["authorization_state"].is_object() && obj["authorization_state"].contains("@type"))
      st = NSStringFromStdString(obj["authorization_state"]["@type"].get<std::string>());
    [bridge_ updateAuthorizationState:st];
    return YES;
  }
  if ([type isEqualToString:@"error"]) {
    int code = obj.contains("code") ? obj["code"].get<int>() : 0;
    NSString *msg = obj.contains("message") ? NSStringFromStdString(obj["message"].get<std::string>()) : @"Unknown";
    [self setAuthBusy:NO message:nil];
    [self setStatusText:[NSString stringWithFormat:@"TDLib error %d: %@", code, msg]];
    return YES;
  }
  if ([type isEqualToString:@"ok"]) {
    NSString *st = [bridge_ authorizationState];
    if ([st isEqualToString:@"authorizationStateWaitCode"]) [self setAuthWindowStatus:@"MFA code sent to the Telegram app on your device."];
    else if ([st isEqualToString:@"authorizationStateWaitPassword"]) [self setAuthWindowStatus:@"Enter your Telegram two-step verification password."];
    return YES;
  }
  if ([type isEqualToString:@"updateConnectionState"]) {
    if (obj.contains("state") && obj["state"].is_object() && obj["state"].contains("@type")) {
      NSString *stt = NSStringFromStdString(obj["state"]["@type"].get<std::string>());
      [self setStatusText:[self readableConnectionState:stt]];
    }
    return YES;
  }
  if ([type isEqualToString:@"updateCall"]) {
    if (obj.contains("call")) {
      NSDictionary *call = (NSDictionary *)NSObjectFromJSON(obj["call"]);
      if (call) {
        activeCallId_ = LongLongValue([call objectForKey:@"id"]);
        long long uid = LongLongValue([call objectForKey:@"user_id"]);
        NSEnumerator *e = [chatsById_ keyEnumerator]; NSNumber *cid;
        while ((cid = [e nextObject])) {
          NSDictionary *chat = [chatsById_ objectForKey:cid];
          NSDictionary *type = [chat objectForKey:@"type"];
          if (LongLongValue([type objectForKey:@"user_id"]) == uid) {
            activeCallChatId_ = [cid longLongValue];
            break;
          }
        }
        NSDictionary *state = [call objectForKey:@"state"];
        if (callState_) [callState_ release];
        callState_ = [StringOrEmpty([state objectForKey:@"@type"]) copy];

        if ([callState_ isEqualToString:@"callStateError"]) {
          NSDictionary *error = [state objectForKey:@"error"];
          NSString *errMsg = StringOrEmpty([error objectForKey:@"message"]);
          [self setStatusText:[NSString stringWithFormat:@"Call failed: %@", errMsg]];
          if (voipSession_ && voipDestroy_) { voipDestroy_(voipSession_); voipSession_ = NULL; }
          [self clearCallState];
        } else if ([callState_ isEqualToString:@"callStateDiscarded"]) {
          if (voipSession_ && voipDestroy_) { voipDestroy_(voipSession_); voipSession_ = NULL; }
          [self clearCallState];
        } else if ([callState_ isEqualToString:@"callStateReady"]) {
          // Start VOIP backend if we have connection details
          if (voipCreate_ && !voipSession_) {
            NSDictionary *callState = [call objectForKey:@"state"];
            NSArray *servers = [callState objectForKey:@"servers"];
            NSString *encKey = StringOrEmpty([callState objectForKey:@"encryption_key"]);
            if ([servers count] > 0) {
              NSDictionary *server = [servers objectAtIndex:0];
              NSString *ip = StringOrEmpty([server objectForKey:@"ip_address"]);
              int port = (int)LongLongValue([server objectForKey:@"port"]);
              NSData *keyData = [encKey dataUsingEncoding:NSUTF8StringEncoding];
              if ([ip length] && port && [keyData length]) {
                voipSession_ = voipCreate_(48000, [ip UTF8String], port, (const unsigned char *)[keyData bytes], (int)[keyData length]);
                [self setStatusText:@"VOIP connected"];
              }
            }
          }
          [self updateCallBar];
        } else {
          [self updateCallBar];
        }
        [self setStatusText:[NSString stringWithFormat:@"Call: %@", callState_]];
      }
    }
    return YES;
  }
  if ([type isEqualToString:@"updateUser"]) {
    NSDictionary *u = (NSDictionary *)NSObjectFromJSON(obj["user"]);
    if (u) {
      NSNumber *uid = [NSNumber numberWithLongLong:LongLongValue([u objectForKey:@"id"])];
      [usersById_ setObject:u forKey:uid];
      if ([[u objectForKey:@"is_me"] boolValue]) {
        meUserId_ = LongLongValue(uid);
        [meUser_ release]; meUser_ = [u retain];
        NSDictionary *pp = [u objectForKey:@"profile_photo"];
        NSString *direct = ProfilePhotoLocalPath(pp);
        if ([direct length]) {
          if (profilePhotoPath_) [profilePhotoPath_ release];
          profilePhotoPath_ = [direct copy];
        } else if ([pp isKindOfClass:[NSDictionary class]]) {
          profilePhotoFileId_ = PhotoSmallFileIdFromPhotoDict(pp);
          if (profilePhotoFileId_) [self requestProfilePhotoDownload];
        }
        [self updateProfilePhoto];
      }
      // Refresh to show sender avatars when user data arrives.
      if (selectedChatId_ != 0) {
        pendingMessageHeightInvalidation_ = YES;
        [self scheduleMessageRefresh];
      }
    }
    return YES;
  }
  if ([type isEqualToString:@"updateUserStatus"]) {
    if (obj.contains("user_id")) {
      long long uid = JSONLongLongAt(obj, "user_id");
      if (uid && ![usersById_ objectForKey:[NSNumber numberWithLongLong:uid]]) {
        json getPayload = {{"@type", "getUser"}, {"user_id", uid}};
        [bridge_ sendJSON:getPayload];
      }
    }
    return YES;
  }
  if ([type isEqualToString:@"user"]) {
    NSDictionary *u = (NSDictionary *)NSObjectFromJSON(obj);
    if (u) {
      NSNumber *uid = [NSNumber numberWithLongLong:LongLongValue([u objectForKey:@"id"])];
      [usersById_ setObject:u forKey:uid];
      if ([[u objectForKey:@"is_me"] boolValue] || expectingGetMe_) {
        meUserId_ = LongLongValue(uid);
        expectingGetMe_ = NO;
        [meUser_ release]; meUser_ = [u retain];
        // Check for profile photo
        NSDictionary *pp = [u objectForKey:@"profile_photo"];
        NSString *direct = ProfilePhotoLocalPath(pp);
        if ([direct length]) {
          if (profilePhotoPath_) [profilePhotoPath_ release];
          profilePhotoPath_ = [direct copy];
          [self updateProfilePhoto];
        } else if ([pp isKindOfClass:[NSDictionary class]]) {
          profilePhotoFileId_ = PhotoSmallFileIdFromPhotoDict(pp);
          if (profilePhotoFileId_) [self requestProfilePhotoDownload];
        } else {
          [self updateProfilePhoto];
        }
      }
    }
    return YES;
  }
  if ([type isEqualToString:@"file"]) {
    NSDictionary *fd = (NSDictionary *)NSObjectFromJSON(obj);
    [self handleFileDictionary:fd];
    return YES;
  }
  if ([type isEqualToString:@"updateFile"]) {
    if (obj.contains("file")) {
      id fo = NSObjectFromJSON(obj["file"]);
      if ([fo isKindOfClass:[NSDictionary class]]) {
        NSDictionary *fd = (NSDictionary *)fo;
        [self handleFileDictionary:fd];
        NSDictionary *local = [fd objectForKey:@"local"];
        NSString *path = StringOrEmpty([local objectForKey:@"path"]);
        long long fid = LongLongValue([fd objectForKey:@"id"]);
        long long expectedSize = LongLongValue([fd objectForKey:@"expected_size"]);
        if (!expectedSize) expectedSize = LongLongValue([fd objectForKey:@"size"]);
        long long downloadedSize = LongLongValue([local objectForKey:@"downloaded_size"]);
        if ([path length] > 0 && fid != 0 && fid == requestedVideoFileId_ && downloadedSize > 0) {
          NSInteger row = [self rowForMessageId:requestedVideoMessageId_];
          if (row >= 0 && !inlineVideoPlayer_) {
            NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
            NSArray *ms = [messagesByChatId_ objectForKey:cid];
            if (ms && (NSUInteger)row < [ms count]) {
              [self presentVideoAtPath:path row:row message:[ms objectAtIndex:(NSUInteger)row]];
            }
          }
        }
      }
    }
    return YES;
  }

  return NO;
}

- (BOOL)handleTDLibChatIdentityDictionary:(NSDictionary *)dict type:(NSString *)type {
  if (!dict) return NO;
  if ([type isEqualToString:@"updateNewChat"]) {
    NSDictionary *chat = [dict objectForKey:@"chat"];
    if (chat) { [self upsertChat:chat]; [self scheduleChatRefresh]; }
    return YES;
  }
  if ([type isEqualToString:@"updateChatTitle"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    NSString *title = StringOrEmpty([dict objectForKey:@"title"]);
    if (chat && [title length]) { [chat setObject:title forKey:@"title"]; [self scheduleChatRefresh]; }
    return YES;
  }

  return NO;
}

- (BOOL)handleTDLibChatPhotoDictionary:(NSDictionary *)dict type:(NSString *)type {
  if (!dict) return NO;
  if ([type isEqualToString:@"updateChatPhoto"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    if (chat) {
      NSDictionary *photo = [dict objectForKey:@"photo"];
      if ([photo isKindOfClass:[NSDictionary class]]) {
        if (photo) {
          [chat setObject:photo forKey:@"photo"];
          long long pfid = PhotoSmallFileIdFromPhotoDict(photo);
          if (pfid) {
            NSNumber *fidk = [NSNumber numberWithLongLong:pfid];
            NSString *localPath = ProfilePhotoLocalPath(photo);
            if ([localPath length]) {
              [filePaths_ setObject:localPath forKey:fidk];
            } else if (![filePaths_ objectForKey:fidk] && ![pendingDownloads_ containsObject:fidk]) {
              [pendingDownloads_ addObject:fidk];
              [bridge_ downloadFile:pfid priority:10];
            }
          }
        }
      } else {
        [chat removeObjectForKey:@"photo"];
      }
      [self scheduleChatRefresh];
    }
    return YES;
  }

  return NO;
}

- (BOOL)handleTDLibChatStateDictionary:(NSDictionary *)dict type:(NSString *)type {
  if (!dict) return NO;
  if ([type isEqualToString:@"updateChatPosition"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    NSDictionary *position = [dict objectForKey:@"position"];
    if (chat && [position isKindOfClass:[NSDictionary class]]) {
      [chat setObject:[NSString stringWithFormat:@"%lld", LongLongValue([position objectForKey:@"order"])] forKey:@"order"];
      [self scheduleChatRefresh];
    }
    return YES;
  }
  if ([type isEqualToString:@"updateChatLastMessage"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    NSDictionary *lm = [dict objectForKey:@"last_message"];
    if (chat && lm) {
      if (lm) { [chat setObject:lm forKey:@"last_message"]; [chat setObject:MessagePreviewFromContent([lm objectForKey:@"content"]) forKey:@"preview"]; }
      [self scheduleChatRefresh];
    }
    return YES;
  }
  if ([type isEqualToString:@"updateChatUnreadCount"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    if (chat) {
      long long uc = LongLongValue([dict objectForKey:@"unread_count"]);
      [chat setObject:[NSNumber numberWithLongLong:uc] forKey:@"unread_count"];
      [self scheduleChatRefresh];
    }
    return YES;
  }
  if ([type isEqualToString:@"updateChatReadInbox"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:LongLongValue([dict objectForKey:@"chat_id"])];
    NSMutableDictionary *chat = [chatsById_ objectForKey:cid];
    if (chat) {
      [chat setObject:[NSNumber numberWithInt:0] forKey:@"unread_count"];
      [self scheduleChatRefresh];
    }
    return YES;
  }

  return NO;
}

- (BOOL)handleTDLibMessageObjectJSON:(const json *)objPtr type:(NSString *)type {
  if (!objPtr) return NO;
  const json &obj = *objPtr;

  if ([type isEqualToString:@"updateNewMessage"]) {
    if (obj.contains("message")) {
      NSDictionary *msg = (NSDictionary *)NSObjectFromJSON(obj["message"]);
      NSNumber *cid = [NSNumber numberWithLongLong:JSONLongLong(obj["message"]["chat_id"])];
      if (msg) [self appendMessage:msg toChatId:cid];
      if ([cid longLongValue] == selectedChatId_) { [self scheduleMessageRefresh]; [self requestFileDownloadForMessage:msg]; }
    }
    [self scheduleChatRefresh];
    return YES;
  }
  if ([type isEqualToString:@"updateMessageContent"]) {
    NSNumber *cid = [NSNumber numberWithLongLong:JSONLongLongAt(obj, "chat_id")];
    NSMutableArray *msgs = [messagesByChatId_ objectForKey:cid];
    long long mid = JSONLongLongAt(obj, "message_id");
    for (NSUInteger i = 0; i < [msgs count]; i++) {
      NSMutableDictionary *msg = [NSMutableDictionary dictionaryWithDictionary:[msgs objectAtIndex:i]];
      if (LongLongValue([msg objectForKey:@"id"]) == mid) {
        if (obj.contains("new_content")) {
          NSDictionary *nc = (NSDictionary *)NSObjectFromJSON(obj["new_content"]);
          if (nc) { [msg setObject:nc forKey:@"content"]; [msgs replaceObjectAtIndex:i withObject:msg]; }
        }
        [messageCellCache_ removeAllObjects];
        pendingMessageHeightInvalidation_ = YES;
        break;
      }
    }
    if (LongLongValue(cid) == selectedChatId_) [self scheduleMessageRefresh];
    return YES;
  }
  if ([type isEqualToString:@"updateDeleteMessages"]) {
    if (obj.contains("chat_id") && obj.contains("message_ids")) {
      long long dcId = JSONLongLongAt(obj, "chat_id");
      if (dcId == selectedChatId_) {
        NSNumber *cidKey = [NSNumber numberWithLongLong:dcId];
        NSMutableArray *msgs = [messagesByChatId_ objectForKey:cidKey];
        NSArray *delIds = (NSArray *)NSObjectFromJSON(obj["message_ids"]);
        if (msgs && delIds) {
          for (NSUInteger i = [msgs count]; i > 0; i--) {
            NSDictionary *m = [msgs objectAtIndex:i - 1];
            long long mid = LongLongValue([m objectForKey:@"id"]);
            for (NSUInteger j = 0; j < [delIds count]; j++) {
              if (LongLongValue([delIds objectAtIndex:j]) == mid) {
                [msgs removeObjectAtIndex:i - 1];
                [messageCellCache_ removeAllObjects];
                pendingMessageHeightInvalidation_ = YES;
                break;
              }
            }
          }
        }
        [self refreshMessages];
      }
      [self scheduleChatRefresh];
    }
    return YES;
  }
  if ([type isEqualToString:@"updateMessageEdited"]) {
    if (selectedChatId_) {
      [bridge_ loadChatHistory:selectedChatId_]; // Refresh to get updated content
    }
    return YES;
  }
  if ([type isEqualToString:@"chats"]) { [bridge_ loadChats]; return YES; }
  if ([type isEqualToString:@"messages"]) {
    long long responseChatId = selectedChatId_;
    if (obj.contains("@extra") && obj["@extra"].is_object() && obj["@extra"].contains("chat_id")) {
      responseChatId = JSONLongLong(obj["@extra"]["chat_id"]);
    }
    NSNumber *cid = [NSNumber numberWithLongLong:responseChatId];
    NSArray *msgs = nil;
    if (obj.contains("messages")) msgs = (NSArray *)NSObjectFromJSON(obj["messages"]);
    [self replaceMessages:(msgs ? msgs : [NSArray array]) chatId:cid];
    if (obj.contains("users")) { [self cacheUsersFromArray:(NSArray *)NSObjectFromJSON(obj["users"])]; }
    if (responseChatId == selectedChatId_) {
      [self refreshMessages];
      NSDictionary *sc = [chatsById_ objectForKey:cid];
      [self setStatusText:StringOrEmpty([sc objectForKey:@"title"])];
      if (historyRetries_ > 0) { historyRetries_--; [bridge_ loadChatHistory:selectedChatId_]; }
    }
    return YES;
  }

  return NO;
}

- (void)handleTDLibObjectJSON:(const json *)objPtr {
  if (!objPtr) return;
  const json &obj = *objPtr;
  if (!obj.is_object()) return;
  NSString *type = obj.contains("@type") ? NSStringFromStdString(obj["@type"].get<std::string>()) : @"";

  if ([self handleTDLibSessionObjectJSON:objPtr type:type]) return;
  NSDictionary *dict = (NSDictionary *)NSObjectFromJSON(obj);
  if (![dict isKindOfClass:[NSDictionary class]]) dict = nil;
  if ([self handleTDLibChatIdentityDictionary:dict type:type]) return;
  if ([self handleTDLibChatPhotoDictionary:dict type:type]) return;
  if ([self handleTDLibChatStateDictionary:dict type:type]) return;
  if ([self handleTDLibMessageObjectJSON:objPtr type:type]) return;
}

@end
