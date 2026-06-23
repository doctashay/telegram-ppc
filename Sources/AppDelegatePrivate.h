#pragma once

#import "AppDelegate.h"

@interface AppDelegate (Private)
- (void)setStatusText:(NSString *)text;
- (void)setAuthWindowStatus:(NSString *)text;
- (void)handleTDLibObjectJSON:(const json *)obj;
- (void)refreshChats;
- (void)refreshMessages;
- (void)scheduleChatRefresh;
- (void)scheduleMessageRefresh;
- (void)performScheduledChatRefresh;
- (void)performScheduledMessageRefresh;
- (void)promptForAuthorizationState:(NSString *)state;
- (void)resumeAuthorizationFlowAfterLaunch;
- (void)configureAuthWindowForState:(NSString *)state;
- (NSString *)selectedPhoneCountryCode;
- (NSString *)normalizedPhoneNumberInput;
- (void)setAuthBusy:(BOOL)busy message:(NSString *)message;
- (IBAction)submitAuth:(id)sender;
- (IBAction)sendCurrentMessage:(id)sender;
- (void)requestFileDownloadForMessage:(NSDictionary *)message;
- (void)handleFileDictionary:(NSDictionary *)fd;
- (NSString *)userNameForSender:(NSDictionary *)senderId;
- (void)cacheUsersFromArray:(NSArray *)users;
- (NSString *)videoPathForMessage:(NSDictionary *)message requestDownload:(BOOL)request;
- (void)presentVideoAtPath:(NSString *)path row:(NSInteger)row message:(NSDictionary *)message;
- (void)showImagePreviewOverlayAtPath:(NSString *)path;
- (void)stopInlineVideoPlayer;
- (NSInteger)rowForMessageId:(long long)messageId;
- (BOOL)isInlineVideoVisible;
- (void)updateInlineVideoVisibility;
- (IBAction)inlineVideoTogglePlay:(id)sender;
- (IBAction)inlineVideoSliderChanged:(id)sender;
- (void)inlineVideoControlTimer:(NSTimer *)timer;
- (void)showAuthWindow;
- (void)hideAuthWindow;
- (void)showMainWindow;
- (IBAction)checkForUpdates:(id)sender;
- (IBAction)showAboutPanel:(id)sender;
- (void)updateProfilePhoto;
- (void)requestProfilePhotoDownload;
- (void)updateMainLayout;
- (IBAction)refreshChatsAction:(id)sender;
- (IBAction)searchChanged:(id)sender;
- (IBAction)focusSearch:(id)sender;
- (void)openSelectedChatDeferred;
- (void)cancelReplyEdit;
- (void)clearCallState;
- (void)updateCallBar;
- (NSString *)formatTimestamp:(long long)timestamp;
- (NSDictionary *)cachedMessageCellDictForMessage:(NSDictionary *)message maxWidth:(CGFloat)maxWidth;
@end
