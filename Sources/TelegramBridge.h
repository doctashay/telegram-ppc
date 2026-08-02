#pragma once

#import "Common.h"

@class AppDelegate;

@interface TelegramBridge : NSObject {
 @private
  void *handle_;
  td_receive_fn tdReceive_;
  td_send_fn tdSend_;
  td_execute_fn tdExecute_;
  td_create_client_id_fn tdCreateClientId_;
  int clientId_;
  AppDelegate *delegate_;
  NSString *authorizationState_;
  BOOL pollAgainScheduled_;
}
- (id)initWithDelegate:(AppDelegate *)delegate;
- (BOOL)loadTDLib;
- (void)start;
- (void)restartClientForLogin;
- (void)discardInterruptedAuthorization;
- (void)poll;
- (void)submitAuthInput:(NSString *)input;
- (void)updateAuthorizationState:(NSString *)state;
- (void)loadChats;
- (void)loadChatHistory:(long long)chatId;
- (void)loadChatHistory:(long long)chatId fromMessageId:(long long)fromMessageId;
- (void)openChat:(long long)chatId;
- (void)editMessageText:(long long)chatId messageId:(long long)messageId text:(NSString *)text;
- (void)deleteMessages:(long long)chatId messageIds:(NSArray *)messageIds;
- (void)createCall:(long long)userId;
- (void)acceptCall:(long long)callId;
- (void)discardCall:(long long)callId isDisconnected:(BOOL)disconnected;
- (void)addReaction:(long long)chatId messageId:(long long)messageId emoji:(NSString *)emoji;
- (void)removeReaction:(long long)chatId messageId:(long long)messageId emoji:(NSString *)emoji;
- (void)sendFile:(long long)chatId filePath:(NSString *)filePath caption:(NSString *)caption;
- (void)sendMessage:(NSString *)text chatId:(long long)chatId replyTo:(long long)replyToId;
- (void)downloadFile:(long long)fileId priority:(int)priority;
- (void)sendJSON:(const json &)payload;
- (NSString *)authorizationState;
- (BOOL)isReady;
@end
