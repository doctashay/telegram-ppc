#import "TelegramBridge.h"
#import "AppDelegatePrivate.h"
#import "FoundationHelpers.h"
#import "OSCompat.h"

static void BridgeLog(NSString *format, ...) {
  if (!getenv("TELEGRAM_PPC_TDLIB_LOG")) return;

  va_list args;
  va_start(args, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);

  NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message];
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:@"/tmp/TelegramPPC.log"];
  if (!handle) {
    [[NSFileManager defaultManager] createFileAtPath:@"/tmp/TelegramPPC.log" contents:nil attributes:nil];
    handle = [NSFileHandle fileHandleForWritingAtPath:@"/tmp/TelegramPPC.log"];
  }
  [handle seekToEndOfFile];
  [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
}

@implementation TelegramBridge

- (id)initWithDelegate:(AppDelegate *)d {
  self = [super init];
  if (self) { delegate_ = d; authorizationState_ = [@"authorizationStateWaitTdlibParameters" retain]; }
  return self;
}

- (void)dealloc {
  [authorizationState_ release];
  if (handle_) { dlclose(handle_); handle_ = NULL; }
  [super dealloc];
}

- (NSString *)authorizationState { return authorizationState_; }

- (BOOL)loadTDLib {
  NSBundle *bundle = [NSBundle mainBundle];
  NSMutableArray *cands = [NSMutableArray array];
  NSString *bl = [[bundle privateFrameworksPath] stringByAppendingPathComponent:@"libtdjson.dylib"];
  if (bl) [cands addObject:bl];
  NSString *ep = [[[NSProcessInfo processInfo] environment] objectForKey:@"TDJSON_PATH"];
  if ([ep length]) [cands addObject:ep];
  for (NSUInteger i = 0; i < [cands count]; i++) {
    NSString *candidate = [cands objectAtIndex:i];
    BridgeLog(@"Trying TDLib candidate %@", candidate);
    handle_ = dlopen([candidate fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
    if (handle_) {
      BridgeLog(@"Loaded TDLib candidate %@", candidate);
      break;
    }
    BridgeLog(@"TDLib candidate failed: %s", dlerror());
  }
  if (!handle_) {
    BridgeLog(@"TDLib not found");
    [delegate_ setStatusText:@"TDLib not found."];
    return NO;
  }
  tdReceive_ = reinterpret_cast<td_receive_fn>(dlsym(handle_, "td_receive"));
  tdSend_ = reinterpret_cast<td_send_fn>(dlsym(handle_, "td_send"));
  tdExecute_ = reinterpret_cast<td_execute_fn>(dlsym(handle_, "td_execute"));
  tdCreateClientId_ = reinterpret_cast<td_create_client_id_fn>(dlsym(handle_, "td_create_client_id"));
  if (!tdReceive_ || !tdSend_ || !tdExecute_ || !tdCreateClientId_) {
    BridgeLog(@"TDLib symbols missing receive=%p send=%p execute=%p create=%p", tdReceive_, tdSend_, tdExecute_, tdCreateClientId_);
    [delegate_ setStatusText:@"TDLib symbols missing."];
    return NO;
  }
  BridgeLog(@"TDLib symbols resolved");
  return YES;
}

- (void)sendJSON:(const json &)payload {
  if (!tdSend_ || clientId_ == 0) {
    [delegate_ setStatusText:@"TDLib is not ready."];
    return;
  }
  NSString *js = JSONStringFromJSON(payload);
  BridgeLog(@"td_send client=%d %@", clientId_, js);
  tdSend_(clientId_, [js UTF8String]);
}

- (void)updateAuthorizationState:(NSString *)state {
  [authorizationState_ release];
  authorizationState_ = [state copy];
  [delegate_ promptForAuthorizationState:authorizationState_];
}

- (void)configureTDLib {
  NSString *root = [@"~/Library/Application Support/PowerPCTelegram" stringByExpandingTildeInPath];
  NSString *files = [root stringByAppendingPathComponent:@"files"];
  EnsureDirectoryExists(root);
  EnsureDirectoryExists(files);
  json p = {{"@type", "setTdlibParameters"}, {"use_test_dc", false},
    {"database_directory", StdStringFromNSString(root)}, {"files_directory", StdStringFromNSString(files)},
    {"use_file_database", true}, {"use_chat_info_database", true}, {"use_message_database", true},
    {"enable_storage_optimizer", true}, {"api_id", kTDLibApiId}, {"api_hash", StdStringFromNSString(kTDLibApiHash)},
    {"system_language_code", "en"}, {"device_model", "Power Mac G5"}, {"system_version", "Mac OS X " TELEGRAM_PPC_SYSTEM_VERSION},
    {"application_version", "0.1-ppc"}};
  [self sendJSON:p];
}

- (void)start {
  BridgeLog(@"Bridge start");
  if (![self loadTDLib]) return;
  const char *logResult = tdExecute_("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":1}");
  BridgeLog(@"setLogVerbosityLevel result %s", logResult ? logResult : "(null)");
  clientId_ = tdCreateClientId_();
  BridgeLog(@"Created TDLib client id %d", clientId_);
  [delegate_ setStatusText:@"TDLib loaded."];
}

- (void)submitAuthInput:(NSString *)input {
  NSString *st = authorizationState_ ? authorizationState_ : @"";
  if ([st isEqualToString:@"authorizationStateWaitTdlibParameters"]) { [self configureTDLib]; return; }
  if ([st isEqualToString:@"authorizationStateWaitEncryptionKey"]) { json p = {{"@type", "checkDatabaseEncryptionKey"}, {"encryption_key", ""}}; [self sendJSON:p]; return; }
  if ([st isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
    NSString *ph = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![ph length]) { [delegate_ setStatusText:@"Enter a phone number."]; return; }
    json p = {{"@type", "setAuthenticationPhoneNumber"}, {"phone_number", StdStringFromNSString(ph)}, {"settings", {{"@type", "phoneNumberAuthenticationSettings"}}}};
    [self sendJSON:p]; return;
  }
  if ([st isEqualToString:@"authorizationStateWaitCode"]) { json p = {{"@type", "checkAuthenticationCode"}, {"code", StdStringFromNSString(input ? input : @"")}}; [self sendJSON:p]; return; }
  if ([st isEqualToString:@"authorizationStateWaitPassword"]) { json p = {{"@type", "checkAuthenticationPassword"}, {"password", StdStringFromNSString(input ? input : @"")}}; [self sendJSON:p]; return; }
}

- (void)loadChats { json p = {{"@type", "loadChats"}, {"chat_list", {{"@type", "chatListMain"}}}, {"limit", 200}}; [self sendJSON:p]; }
- (void)openChat:(long long)cid { json p = {{"@type", "openChat"}, {"chat_id", cid}}; [self sendJSON:p]; }
- (void)loadChatHistory:(long long)cid { [self loadChatHistory:cid fromMessageId:0]; }
- (void)loadChatHistory:(long long)cid fromMessageId:(long long)fromMessageId {
  int offset = fromMessageId ? 0 : 0;
  json p = {{"@type", "getChatHistory"}, {"chat_id", cid}, {"from_message_id", fromMessageId}, {"offset", offset}, {"limit", 100}, {"only_local", false}, {"@extra", {{"chat_id", cid}, {"from_message_id", fromMessageId}}}};
  [self sendJSON:p];
}
- (void)sendMessage:(NSString *)txt chatId:(long long)cid replyTo:(long long)replyToId {
  if (![txt length] || !cid) return;
  json p = {{"@type", "sendMessage"}, {"chat_id", cid}, {"message_thread_id", 0},
    {"input_message_content", {{"@type", "inputMessageText"}, {"text", {{"@type", "formattedText"}, {"text", StdStringFromNSString(txt)}, {"entities", json::array()}}}, {"disable_web_page_preview", false}, {"clear_draft", false}}}};
  if (replyToId != 0) p["reply_to"] = {{"@type", "inputMessageReplyToMessage"}, {"message_id", replyToId}};
  [self sendJSON:p];
}
- (void)editMessageText:(long long)chatId messageId:(long long)messageId text:(NSString *)txt {
  if (![txt length] || !chatId || !messageId) return;
  json p = {{"@type", "editMessageText"}, {"chat_id", chatId}, {"message_id", messageId},
    {"input_message_content", {{"@type", "inputMessageText"}, {"text", {{"@type", "formattedText"}, {"text", StdStringFromNSString(txt)}, {"entities", json::array()}}}, {"disable_web_page_preview", false}, {"clear_draft", false}}}};
  [self sendJSON:p];
}
- (void)deleteMessages:(long long)chatId messageIds:(NSArray *)messageIds {
  if (!chatId || ![messageIds count]) return;
  std::vector<long long> ids;
  for (NSUInteger i = 0; i < [messageIds count]; i++) {
    ids.push_back(LongLongValue([messageIds objectAtIndex:i]));
  }
  json p = {{"@type", "deleteMessages"}, {"chat_id", chatId}, {"message_ids", ids}, {"revoke", true}};
  [self sendJSON:p];
}
- (void)createCall:(long long)userId {
  if (!userId) return;
  json p = {{"@type", "createCall"}, {"user_id", userId}, {"protocol", {{"@type", "callProtocol"}, {"udp_p2p", true}, {"udp_reflector", true}, {"min_layer", 65}, {"max_layer", 92}, {"library_versions", json::array({"2.4.4", "3.0.0", "4.0.0"})}}}};
  [self sendJSON:p];
}
- (void)acceptCall:(long long)callId {
  if (!callId) return;
  json p = {{"@type", "acceptCall"}, {"call_id", callId}, {"protocol", {{"@type", "callProtocol"}, {"udp_p2p", true}, {"udp_reflector", true}, {"min_layer", 65}, {"max_layer", 92}, {"library_versions", json::array({"2.4.4", "3.0.0", "4.0.0"})}}}};
  [self sendJSON:p];
}
- (void)discardCall:(long long)callId isDisconnected:(BOOL)disconnected {
  if (!callId) return;
  json p = {{"@type", "discardCall"}, {"call_id", callId}, {"is_disconnected", disconnected}};
  [self sendJSON:p];
}
- (void)downloadFile:(long long)fid priority:(int)pri {
  if (!fid) return;
  json p = {{"@type", "downloadFile"}, {"file_id", fid}, {"priority", pri}, {"offset", 0}, {"limit", 0}, {"synchronous", false}};
  [self sendJSON:p];
}
- (void)addReaction:(long long)chatId messageId:(long long)messageId emoji:(NSString *)emoji {
  if (!chatId || !messageId || ![emoji length]) return;
  json p = {{"@type", "addMessageReaction"}, {"chat_id", chatId}, {"message_id", messageId},
    {"reaction_type", {{"@type", "reactionTypeEmoji"}, {"emoji", StdStringFromNSString(emoji)}}}};
  [self sendJSON:p];
}
- (void)removeReaction:(long long)chatId messageId:(long long)messageId emoji:(NSString *)emoji {
  if (!chatId || !messageId || ![emoji length]) return;
  json p = {{"@type", "removeMessageReaction"}, {"chat_id", chatId}, {"message_id", messageId},
    {"reaction_type", {{"@type", "reactionTypeEmoji"}, {"emoji", StdStringFromNSString(emoji)}}}};
  [self sendJSON:p];
}
- (void)sendFile:(long long)chatId filePath:(NSString *)filePath caption:(NSString *)caption {
  if (!chatId || ![filePath length]) return;
  NSString *cap = caption ? caption : @"";
  json p = {{"@type", "sendMessage"}, {"chat_id", chatId}, {"message_thread_id", 0},
    {"input_message_content", {{"@type", "inputMessageDocument"},
      {"document", {{"@type", "inputFileLocal"}, {"path", StdStringFromNSString(filePath)}}},
      {"caption", {{"@type", "formattedText"}, {"text", StdStringFromNSString(cap)}, {"entities", json::array()}}},
      {"disable_content_type_detection", false}}}};
  [self sendJSON:p];
}

- (void)poll {
  if (!tdReceive_) return;
  pollAgainScheduled_ = NO;
  int processed = 0;
  const int maxPerTick = 25;
  while (processed < maxPerTick) {
    const char *r = tdReceive_(0.0);
    if (!r) break;
    processed++;
    json o = JSONFromCString(r);
    BridgeLog(@"td_receive %@", NSStringFromStdString(o.dump()));
    if (!o.is_null()) [delegate_ handleTDLibObjectJSON:&o];
  }
  if (processed == maxPerTick && !pollAgainScheduled_) {
    pollAgainScheduled_ = YES;
    [self performSelector:@selector(poll) withObject:nil afterDelay:0.01];
  }
}

@end
