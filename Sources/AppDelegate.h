#pragma once

#import "Common.h"

@class TelegramBridge;
@class VideoPlayerView;
@class PlaybackButtonView;

@interface AppDelegate : NSObject {
 @private
  // Auth window
  NSWindow *authWindow_;
  NSImageView *authIconView_;
  NSTextField *authTitleLabel_;
  NSTextField *authSubtitleLabel_;
  NSTextField *authCountryLabel_;
  NSPopUpButton *authCountryPopup_;
  NSTextField *authPhoneLabel_;
  NSTextField *authPhoneField_;
  NSTextField *authCodeLabel_;
  NSTextField *authCodeField_;
  NSButton *authSubmitBtn_;
  NSTextField *authStatusLabel_;
  NSBox *authProxyBox_;
  NSButton *authProxyEnabledBtn_;
  NSButton *authProxyCheckBtn_;
  NSTextField *authProxyTypeLabel_;
  NSPopUpButton *authProxyTypePopup_;
  NSTextField *authProxyHostLabel_;
  NSTextField *authProxyHostField_;
  NSTextField *authProxyPortLabel_;
  NSTextField *authProxyPortField_;
  NSTextField *authProxyUserField_;
  NSTextField *authProxyPasswordField_;
  NSTextField *authProxySecretField_;
  NSTextField *authProxyUserLabel_;
  NSTextField *authProxyPasswordLabel_;
  NSTextField *authProxySecretLabel_;

  // Main window
  NSWindow *mainWindow_;
  NSTextField *statusLabel_;
  NSView *statusBar_;
  NSSplitView *mainSplitView_;
  NSView *conversationView_;
  NSScrollView *chatScrollView_;
  NSScrollView *messageScrollView_;
  NSView *composeBar_;
  NSTableView *chatTable_;
  NSTableView *messageTable_;
  NSTextField *composeField_;
  NSButton *sendButton_;
  NSButton *attachButton_;
  NSButton *profileButton_;
  NSSearchField *searchField_;
  NSString *chatFilter_;

  // Data
  NSMutableArray *chatIds_;
  NSMutableDictionary *chatsById_;
  NSMutableDictionary *messagesByChatId_;
  NSMutableDictionary *messageCellCache_;
  long long selectedChatId_;
  int historyRetries_;
  TelegramBridge *bridge_;
  BOOL authRequestInFlight_;
  BOOL authProxyConfigurationInFlight_;
  BOOL authProxyCheckOnly_;
  int pendingAuthProxyId_;
  NSString *pendingAuthPhoneNumber_;
  NSString *verifiedAuthProxySettings_;
  BOOL startupAuthorizationRecovery_;
  BOOL resettingInterruptedAuthorization_;
  long long meUserId_;
  NSMutableDictionary *usersById_;
  NSMutableDictionary *filePaths_;
  NSMutableSet *pendingDownloads_;
  BOOL expectingGetMe_;
  BOOL tdlibConfigured_;
  BOOL chatRefreshScheduled_;
  BOOL messageRefreshScheduled_;
  BOOL logoutInProgress_;
  BOOL pendingMessageHeightInvalidation_;
  CGFloat lastMessageTableWidth_;
  NSDictionary *meUser_;
  long long profilePhotoFileId_;
  NSString *profilePhotoPath_;

  // Reply / edit state
  long long replyToMessageId_;
  long long editMessageId_;
  NSTextField *replyBarLabel_;
  NSButton *cancelReplyBtn_;
  NSView *replyBarContainer_;

  // Call state
  long long activeCallId_;
  long long activeCallChatId_;
  NSString *callState_;
  NSButton *callButton_;
  NSView *callBar_;
  NSTextField *callBarLabel_;
  NSButton *callAcceptBtn_;
  NSButton *callDeclineBtn_;
  NSButton *callEndBtn_;

  // VOIP backend
  void *voipHandle_;
  void *(*voipCreate_)(int, const char *, int, const unsigned char *, int);
  void (*voipDestroy_)(void *);
  void *voipSession_;

  // Expanded messages
  NSMutableSet *expandedMessages_;

  // Inline media player
  NSView *inlineVideoContainer_;
  VideoPlayerView *inlineVideoPlayer_;
  PlaybackButtonView *inlineVideoPlayButton_;
  NSSlider *inlineVideoSlider_;
  NSTextField *inlineVideoTimeLabel_;
  NSTimer *inlineVideoControlTimer_;
  BOOL inlineVideoUserPaused_;
  BOOL inlineVideoAutoPaused_;
  BOOL inlineVideoStopping_;
  long long requestedVideoFileId_;
  long long requestedVideoMessageId_;
}
- (void)createMenus;
@end
