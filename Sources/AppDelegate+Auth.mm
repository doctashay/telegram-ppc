#import "AppDelegatePrivate.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MediaViews.h"
#import "MessageCell.h"
#import "MessageContent.h"
#import "TelegramBridge.h"
#import "VideoPlayerView.h"

@implementation AppDelegate (Auth)

- (void)setAuthWindowStatus:(NSString *)t {
  [authStatusLabel_ setStringValue:t ? t : @""];
}

- (void)setAuthBusy:(BOOL)busy message:(NSString *)msg {
  authRequestInFlight_ = busy;
  if (authSubmitBtn_) [authSubmitBtn_ setEnabled:!busy];
  if (msg) { [self setAuthWindowStatus:msg]; [self setStatusText:msg]; }
}

- (NSArray *)phoneCountryItems {
  static const char *items[][3] = {
    {"United States / Canada (+1)", "+1", "1f1fa-1f1f8"},
    {"United Kingdom (+44)", "+44", "1f1ec-1f1e7"},
    {"Australia (+61)", "+61", "1f1e6-1f1fa"},
    {"Germany (+49)", "+49", "1f1e9-1f1ea"},
    {"France (+33)", "+33", "1f1eb-1f1f7"},
    {"Italy (+39)", "+39", "1f1ee-1f1f9"},
    {"Spain (+34)", "+34", "1f1ea-1f1f8"},
    {"Netherlands (+31)", "+31", "1f1f3-1f1f1"},
    {"Sweden (+46)", "+46", "1f1f8-1f1ea"},
    {"Brazil (+55)", "+55", "1f1e7-1f1f7"},
    {"Mexico (+52)", "+52", "1f1f2-1f1fd"},
    {"India (+91)", "+91", "1f1ee-1f1f3"},
    {"Japan (+81)", "+81", "1f1ef-1f1f5"},
    {"South Korea (+82)", "+82", "1f1f0-1f1f7"},
    {"Russia (+7)", "+7", "1f1f7-1f1fa"},
    {"Ukraine (+380)", "+380", "1f1fa-1f1e6"},
    {"Turkey (+90)", "+90", "1f1f9-1f1f7"},
    {"Israel (+972)", "+972", "1f1ee-1f1f1"},
    {"Saudi Arabia (+966)", "+966", "1f1f8-1f1e6"},
    {"United Arab Emirates (+971)", "+971", "1f1e6-1f1ea"}
  };
  NSMutableArray *countries = [NSMutableArray array];
  for (NSUInteger i = 0; i < (sizeof(items) / sizeof(items[0])); i++) {
    NSString *title = [NSString stringWithUTF8String:items[i][0]];
    NSString *code = [NSString stringWithUTF8String:items[i][1]];
    NSString *flag = [NSString stringWithUTF8String:items[i][2]];
    [countries addObject:[NSDictionary dictionaryWithObjectsAndKeys:title, @"title", code, @"code", flag, @"flag", nil]];
  }
  return countries;
}

- (NSString *)selectedPhoneCountryCode {
  id rep = authCountryPopup_ ? [[authCountryPopup_ selectedItem] representedObject] : nil;
  return [rep isKindOfClass:[NSString class]] && [rep length] ? rep : @"+1";
}

- (NSString *)normalizedPhoneNumberInput {
  NSString *raw = authPhoneField_ ? [authPhoneField_ stringValue] : @"";
  NSMutableString *digits = [NSMutableString string];
  for (NSUInteger i = 0; i < [raw length]; i++) {
    unichar ch = [raw characterAtIndex:i];
    if (ch >= '0' && ch <= '9') [digits appendFormat:@"%C", ch];
    else if (ch == '+' && [digits length] == 0) [digits appendString:@"+"];
  }
  if ([digits hasPrefix:@"+"]) return digits;
  return [[self selectedPhoneCountryCode] stringByAppendingString:digits];
}

- (void)configureAuthWindowForState:(NSString *)state {
  BOOL phoneStep = [state isEqualToString:@"authorizationStateWaitPhoneNumber"] || ![state length];
  BOOL passwordStep = [state isEqualToString:@"authorizationStateWaitPassword"];
  if (authTitleLabel_) {
    [authTitleLabel_ setStringValue:(phoneStep ? @"Enter your phone number to sign into Telegram" : (passwordStep ? @"Enter your Telegram password" : @"Enter your Telegram authorization code"))];
  }
  [authCountryLabel_ setHidden:!phoneStep];
  [authCountryPopup_ setHidden:!phoneStep];
  [authPhoneLabel_ setHidden:!phoneStep];
  [authPhoneField_ setHidden:!phoneStep];
  [authCodeLabel_ setHidden:phoneStep];
  [authCodeField_ setHidden:phoneStep];
  [authCodeLabel_ setStringValue:(passwordStep ? @"Password:" : @"Authorization Code:")];
  [authSubmitBtn_ setTitle:(phoneStep ? @"Continue" : @"Sign In")];
  [authWindow_ makeFirstResponder:(phoneStep ? (NSResponder *)authPhoneField_ : (NSResponder *)authCodeField_)];
}

- (void)showAuthWindow {
  if (authWindow_) {
    [NSApp activateIgnoringOtherApps:YES];
    [authWindow_ makeKeyAndOrderFront:nil];
    [self configureAuthWindowForState:[bridge_ authorizationState]];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 500, 250);
  NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
  frame.origin.x = (screenFrame.size.width - frame.size.width) / 2.0;
  frame.origin.y = (screenFrame.size.height - frame.size.height) / 2.0;

  authWindow_ = [[NSWindow alloc] initWithContentRect:frame styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:NO];
  [authWindow_ setTitle:@"Log In to Sailplane"];
  NSView *cv = [authWindow_ contentView];
  CGFloat w = frame.size.width;

  authTitleLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(26, frame.size.height - 46, w - 52, 24)] autorelease];
  [authTitleLabel_ setBezeled:NO]; [authTitleLabel_ setDrawsBackground:NO]; [authTitleLabel_ setEditable:NO]; [authTitleLabel_ setSelectable:NO];
  [authTitleLabel_ setFont:[NSFont boldSystemFontOfSize:14]];
  [authTitleLabel_ setStringValue:@"Enter your phone number to sign into Telegram"];
  [cv addSubview:authTitleLabel_];

  CGFloat labelX = 30.0, labelW = 118.0, fieldX = 158.0, fieldW = w - fieldX - 30.0;
  authCountryLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(labelX, frame.size.height - 86, labelW, 17)] autorelease];
  [authCountryLabel_ setBezeled:NO]; [authCountryLabel_ setDrawsBackground:NO]; [authCountryLabel_ setEditable:NO]; [authCountryLabel_ setSelectable:NO];
  [authCountryLabel_ setFont:[NSFont systemFontOfSize:12]]; [authCountryLabel_ setStringValue:@"Country:"];
  [authCountryLabel_ setAlignment:NSRightTextAlignment];
  [cv addSubview:authCountryLabel_];
  authCountryPopup_ = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 92, fieldW, 26) pullsDown:NO] autorelease];
  NSArray *countries = [self phoneCountryItems];
  for (NSUInteger i = 0; i < [countries count]; i++) {
    NSDictionary *item = [countries objectAtIndex:i];
    [authCountryPopup_ addItemWithTitle:StringOrEmpty([item objectForKey:@"title"])];
    NSMenuItem *menuItem = [authCountryPopup_ lastItem];
    [menuItem setRepresentedObject:StringOrEmpty([item objectForKey:@"code"])];
    NSImage *flagImage = TwemojiImageForKey(StringOrEmpty([item objectForKey:@"flag"]));
    if (flagImage) {
      NSImage *popupFlag = [[flagImage copy] autorelease];
      [popupFlag setSize:NSMakeSize(16.0, 16.0)];
      [menuItem setImage:popupFlag];
    }
  }
  [cv addSubview:authCountryPopup_];

  authPhoneLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(labelX, frame.size.height - 126, labelW, 17)] autorelease];
  [authPhoneLabel_ setBezeled:NO]; [authPhoneLabel_ setDrawsBackground:NO]; [authPhoneLabel_ setEditable:NO]; [authPhoneLabel_ setSelectable:NO];
  [authPhoneLabel_ setFont:[NSFont systemFontOfSize:12]]; [authPhoneLabel_ setStringValue:@"Phone number:"];
  [authPhoneLabel_ setAlignment:NSRightTextAlignment];
  [cv addSubview:authPhoneLabel_];
  authPhoneField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 132, fieldW, 22)] autorelease];
  [authPhoneField_ setFont:[NSFont systemFontOfSize:12]];
  [cv addSubview:authPhoneField_];

  authCodeLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(labelX, frame.size.height - 126, labelW, 17)] autorelease];
  [authCodeLabel_ setBezeled:NO]; [authCodeLabel_ setDrawsBackground:NO]; [authCodeLabel_ setEditable:NO]; [authCodeLabel_ setSelectable:NO];
  [authCodeLabel_ setFont:[NSFont systemFontOfSize:12]]; [authCodeLabel_ setStringValue:@"Authorization Code:"];
  [authCodeLabel_ setAlignment:NSRightTextAlignment];
  [cv addSubview:authCodeLabel_];
  authCodeField_ = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 132, fieldW, 22)] autorelease];
  [authCodeField_ setFont:[NSFont systemFontOfSize:12]];
  [cv addSubview:authCodeField_];

  authSubmitBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(w - 126, 48, 96, 32)] autorelease];
  [authSubmitBtn_ setTitle:@"Continue"];
  [authSubmitBtn_ setBezelStyle:NSRoundedBezelStyle];
  [authSubmitBtn_ setTarget:self]; [authSubmitBtn_ setAction:@selector(submitAuth:)];
  [cv addSubview:authSubmitBtn_];
  [authWindow_ setDefaultButtonCell:[authSubmitBtn_ cell]];

  authStatusLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(30, 18, w - 60, 18)] autorelease];
  [authStatusLabel_ setBezeled:NO]; [authStatusLabel_ setDrawsBackground:NO]; [authStatusLabel_ setEditable:NO]; [authStatusLabel_ setSelectable:NO];
  [authStatusLabel_ setFont:[NSFont systemFontOfSize:11]];
  [authStatusLabel_ setTextColor:[NSColor grayColor]];
  [cv addSubview:authStatusLabel_];

  [self configureAuthWindowForState:[bridge_ authorizationState]];
  [authWindow_ center];
  [NSApp activateIgnoringOtherApps:YES];
  [authWindow_ makeKeyAndOrderFront:nil];
  [authWindow_ orderFrontRegardless];
}

- (void)hideAuthWindow {
  if (authWindow_) {
    [authWindow_ orderOut:nil];
    [authWindow_ release]; authWindow_ = nil;
    authTitleLabel_ = nil; authCountryLabel_ = nil; authCountryPopup_ = nil; authPhoneLabel_ = nil;
    authPhoneField_ = nil; authCodeLabel_ = nil; authCodeField_ = nil; authSubmitBtn_ = nil; authStatusLabel_ = nil;
  }
}

- (void)resumeAuthorizationFlowAfterLaunch {
  NSString *state = [bridge_ authorizationState];
  if ([state isEqualToString:@"authorizationStateWaitTdlibParameters"] ||
      [state isEqualToString:@"authorizationStateWaitEncryptionKey"] ||
      [state isEqualToString:@"authorizationStateWaitPhoneNumber"] ||
      [state isEqualToString:@"authorizationStateWaitCode"] ||
      [state isEqualToString:@"authorizationStateWaitPassword"] ||
      [state isEqualToString:@"authorizationStateReady"]) {
    [self promptForAuthorizationState:state];
  }
}

- (IBAction)submitAuth:(id)sender {
  (void)sender;
  if (authRequestInFlight_) { [self setAuthWindowStatus:@"Already in progress. Wait..."]; return; }
  NSString *st = [bridge_ authorizationState];
  if ([st isEqualToString:@"authorizationStateWaitTdlibParameters"]) {
    [self setAuthBusy:YES message:@"Initializing..."];
  } else if ([st isEqualToString:@"authorizationStateWaitEncryptionKey"]) {
    [self setAuthBusy:YES message:@"Opening database..."];
  } else if ([st isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
    NSString *phone = [self normalizedPhoneNumberInput];
    NSString *country = [self selectedPhoneCountryCode];
    if ([phone length] <= [country length]) {
      [self setAuthWindowStatus:@"Enter your phone number."];
      [authWindow_ makeFirstResponder:authPhoneField_];
      return;
    }
    [[NSUserDefaults standardUserDefaults] setObject:phone forKey:@"SailplanePendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self setAuthBusy:YES message:@"Sending phone number..."];
  } else if ([st isEqualToString:@"authorizationStateWaitCode"]) {
    [self setAuthBusy:YES message:@"Checking authorization code..."];
  } else if ([st isEqualToString:@"authorizationStateWaitPassword"]) {
    [self setAuthBusy:YES message:@"Checking 2FA password..."];
  }
  NSString *input = [authCodeField_ stringValue];
  if ([st isEqualToString:@"authorizationStateWaitPhoneNumber"]) input = [self normalizedPhoneNumberInput];
  [bridge_ submitAuthInput:input];
}

- (void)promptForAuthorizationState:(NSString *)state {
  [self setAuthBusy:NO message:nil];

  if ([state isEqualToString:@"authorizationStateWaitTdlibParameters"]) {
    [self showAuthWindow];
    [self configureAuthWindowForState:state];
    if (!tdlibConfigured_) {
      tdlibConfigured_ = YES;
      [self setAuthBusy:YES message:@"Configuring TDLib..."];
      [bridge_ submitAuthInput:@""];
    }
  } else if ([state isEqualToString:@"authorizationStateWaitEncryptionKey"]) {
    [self showAuthWindow];
    [self configureAuthWindowForState:state];
    [self setAuthBusy:YES message:@"Opening local database..."];
    [bridge_ submitAuthInput:@""];
  } else if ([state isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
    [self showAuthWindow];
    [self configureAuthWindowForState:state];
    NSString *pendingPhone = [[NSUserDefaults standardUserDefaults] stringForKey:@"SailplanePendingPhoneNumber"];
    if (![pendingPhone length]) {
      pendingPhone = [[NSUserDefaults standardUserDefaults] stringForKey:@"TelegramPPCPendingPhoneNumber"];
    }
    if ([pendingPhone length] && authPhoneField_ && ![[authPhoneField_ stringValue] length]) {
      [authPhoneField_ setStringValue:pendingPhone];
    }
    [self setAuthWindowStatus:@"Select your country code and enter your phone number."];
  } else if ([state isEqualToString:@"authorizationStateWaitCode"]) {
    [self showAuthWindow];
    [self configureAuthWindowForState:state];
    [authCodeField_ setStringValue:@""];
    [self setAuthWindowStatus:@"MFA code sent to the Telegram app on your device."];
  } else if ([state isEqualToString:@"authorizationStateWaitPassword"]) {
    [self showAuthWindow];
    [self configureAuthWindowForState:state];
    [authCodeField_ setStringValue:@""];
    [self setAuthWindowStatus:@"Enter your Telegram two-step verification password."];
  } else if ([state isEqualToString:@"authorizationStateReady"]) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SailplanePendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegramPPCPendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self hideAuthWindow];
    [self showMainWindow];
    expectingGetMe_ = YES;
    json p = {{"@type", "getMe"}};
    [bridge_ sendJSON:p];
    [bridge_ loadChats];
    [self setStatusText:@"Authorized. Loading chats..."];
  } else {
    [self setStatusText:state];
  }
}

@end
