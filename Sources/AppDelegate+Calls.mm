#import "AppDelegatePrivate.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MediaViews.h"
#import "MessageCell.h"
#import "MessageContent.h"
#import "TelegramBridge.h"
#import "VideoPlayerView.h"

@implementation AppDelegate (Calls)

- (void)callButtonClicked:(id)sender {
  (void)sender;
  if (!selectedChatId_ || activeCallId_) return;
  NSDictionary *chat = [chatsById_ objectForKey:[NSNumber numberWithLongLong:selectedChatId_]];
  if (!chat) return;
  // Private chats have user_id in the chat type
  NSDictionary *type = [chat objectForKey:@"type"];
  long long uid = LongLongValue([type objectForKey:@"user_id"]);
  if (!uid) uid = meUserId_; // Fallback
  if (uid && uid != meUserId_) {
    [bridge_ createCall:uid];
    [self setStatusText:@"Calling..."];
  }
}

- (void)acceptCallAction:(id)sender {
  (void)sender;
  if (activeCallId_) [bridge_ acceptCall:activeCallId_];
}

- (void)declineCallAction:(id)sender {
  (void)sender;
  if (activeCallId_) {
    [bridge_ discardCall:activeCallId_ isDisconnected:NO];
    [self clearCallState];
  }
}

- (void)endCallAction:(id)sender {
  (void)sender;
  if (activeCallId_) {
    [bridge_ discardCall:activeCallId_ isDisconnected:YES];
    [self clearCallState];
  }
}

- (void)clearCallState {
  if (voipSession_ && voipDestroy_) { voipDestroy_(voipSession_); voipSession_ = NULL; }
  activeCallId_ = 0; activeCallChatId_ = 0;
  [callState_ release]; callState_ = nil;
  [callBar_ setHidden:YES]; [callAcceptBtn_ setHidden:YES]; [callDeclineBtn_ setHidden:YES]; [callEndBtn_ setHidden:YES];
  [self updateMainLayout];
}

- (void)updateCallBar {
  if (!activeCallId_) { [callBar_ setHidden:YES]; [self updateMainLayout]; return; }
  [callBar_ setHidden:NO];
  NSString *state = callState_ ? callState_ : @"";
  BOOL incoming = [state isEqualToString:@"callStatePending"] && activeCallChatId_;
  BOOL connected = [state isEqualToString:@"callStateReady"];

  NSString *callerName = @"Unknown";
  if (activeCallChatId_) {
    NSDictionary *chat = [chatsById_ objectForKey:[NSNumber numberWithLongLong:activeCallChatId_]];
    callerName = StringOrEmpty([chat objectForKey:@"title"]);
  }

  if (connected) {
    [callAcceptBtn_ setHidden:YES]; [callDeclineBtn_ setHidden:YES]; [callEndBtn_ setHidden:NO];
    [callBarLabel_ setStringValue:[NSString stringWithFormat:@"In call with %@", callerName]];
  } else if (incoming) {
    [callAcceptBtn_ setHidden:NO]; [callDeclineBtn_ setHidden:NO]; [callEndBtn_ setHidden:YES];
    [callBarLabel_ setStringValue:[NSString stringWithFormat:@"%@ is calling...", callerName]];
  } else {
    [callAcceptBtn_ setHidden:YES]; [callDeclineBtn_ setHidden:YES]; [callEndBtn_ setHidden:NO];
    [callBarLabel_ setStringValue:[NSString stringWithFormat:@"Calling %@...", callerName]];
  }
  [self updateMainLayout];
}

@end
