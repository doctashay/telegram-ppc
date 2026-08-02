#import "AppDelegatePrivate.h"
#import "EmojiText.h"
#import "FoundationHelpers.h"
#import "ImageDrawing.h"
#import "MediaViews.h"
#import "MessageCell.h"
#import "MessageContent.h"
#import "TelegramBridge.h"
#import "VideoPlayerView.h"

static NSTextField *AuthLabel(NSString *title, NSRect frame, NSTextAlignment alignment, NSFont *font) {
  NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
  [label setBezeled:NO]; [label setDrawsBackground:NO]; [label setEditable:NO]; [label setSelectable:NO];
  [label setStringValue:title ? title : @""];
  [label setAlignment:alignment];
  if (font) [label setFont:font];
  return label;
}

@implementation AppDelegate (Auth)

- (void)setAuthWindowStatus:(NSString *)t {
  [authStatusLabel_ setStringValue:t ? t : @""];
  [authStatusLabel_ setTextColor:[NSColor grayColor]];
}

- (void)setAuthBusy:(BOOL)busy message:(NSString *)msg {
  authRequestInFlight_ = busy;
  if (authSubmitBtn_) [authSubmitBtn_ setEnabled:!busy];
  [self updateProxyFieldVisibility];
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
  BOOL explicitInternational = NO;
  for (NSUInteger i = 0; i < [raw length]; i++) {
    unichar ch = [raw characterAtIndex:i];
    if (ch >= '0' && ch <= '9') [digits appendFormat:@"%C", ch];
    else if (ch == '+' && [digits length] == 0) explicitInternational = YES;
  }
  if (![digits length]) return @"";
  NSString *country = [self selectedPhoneCountryCode];
  NSString *countryDigits = [country hasPrefix:@"+"] ? [country substringFromIndex:1] : country;
  if (explicitInternational) return [@"+" stringByAppendingString:digits];
  if ([digits hasPrefix:countryDigits] && [digits length] > ([countryDigits length] + 5)) return [@"+" stringByAppendingString:digits];
  if ([countryDigits isEqualToString:@"1"] && [digits length] == 11 && [digits hasPrefix:@"1"]) return [@"+" stringByAppendingString:digits];
  return [country stringByAppendingString:digits];
}

- (void)layoutAuthWindowForPhoneStep:(BOOL)phoneStep proxyEnabled:(BOOL)proxyEnabled {
  if (!authWindow_) return;

  CGFloat width = 560.0;
  CGFloat height = phoneStep ? (proxyEnabled ? 390.0 : 310.0) : 230.0;
  NSView *contentView = [authWindow_ contentView];
  CGFloat currentHeight = NSHeight([contentView frame]);
  if (fabs(currentHeight - height) > 0.5) {
    NSRect windowFrame = [authWindow_ frame];
    CGFloat top = NSMaxY(windowFrame);
    windowFrame.size.height += height - currentHeight;
    windowFrame.origin.y = top - windowFrame.size.height;
    [authWindow_ setFrame:windowFrame display:YES];
  }

  [authIconView_ setFrame:NSMakeRect(28, height - 72, 48, 48)];
  [authTitleLabel_ setFrame:NSMakeRect(92, height - 50, width - 124, 24)];
  [authSubtitleLabel_ setFrame:NSMakeRect(94, height - 72, width - 126, 18)];

  CGFloat labelX = 42.0, labelWidth = 116.0, fieldX = 168.0, fieldWidth = width - fieldX - 42.0;
  [authCountryLabel_ setFrame:NSMakeRect(labelX, height - 119, labelWidth, 17)];
  [authCountryPopup_ setFrame:NSMakeRect(fieldX, height - 124, fieldWidth, 26)];
  [authPhoneLabel_ setFrame:NSMakeRect(labelX, height - 157, labelWidth, 17)];
  [authPhoneField_ setFrame:NSMakeRect(fieldX, height - 160, fieldWidth, 22)];
  [authCodeLabel_ setFrame:NSMakeRect(labelX, height - 157, labelWidth, 17)];
  [authCodeField_ setFrame:NSMakeRect(fieldX, height - 160, fieldWidth, 22)];

  if (phoneStep) {
    [authProxyBox_ setFrame:(proxyEnabled
      ? NSMakeRect(32, 76, width - 64, 134)
      : NSMakeRect(32, 76, width - 64, 58))];
    [authProxyEnabledBtn_ setFrame:(proxyEnabled
      ? NSMakeRect(14, 86, 112, 22)
      : NSMakeRect(14, 8, 112, 22))];
  }

  [authSubmitBtn_ setFrame:NSMakeRect(width - 138, 20, 96, 28)];
  [authStatusLabel_ setFrame:NSMakeRect(42, 26, width - 196, 18)];
}

- (void)updateProxyFieldVisibility {
  BOOL enabled = authProxyEnabledBtn_ && ([authProxyEnabledBtn_ state] == NSOnState);
  BOOL controlsEnabled = enabled && !authRequestInFlight_;
  NSString *type = authProxyTypePopup_ ? [[authProxyTypePopup_ selectedItem] representedObject] : @"socks5";
  BOOL mtproto = [type isEqualToString:@"mtproto"];
  [authProxyTypeLabel_ setHidden:!enabled];
  [authProxyTypePopup_ setHidden:!enabled];
  [authProxyHostLabel_ setHidden:!enabled];
  [authProxyHostField_ setHidden:!enabled];
  [authProxyPortLabel_ setHidden:!enabled];
  [authProxyPortField_ setHidden:!enabled];
  [authProxyCheckBtn_ setHidden:!enabled];
  [authProxyEnabledBtn_ setEnabled:!authRequestInFlight_];
  [authProxyTypePopup_ setEnabled:controlsEnabled];
  [authProxyHostField_ setEnabled:controlsEnabled];
  [authProxyPortField_ setEnabled:controlsEnabled];
  [authProxyUserField_ setEnabled:controlsEnabled && !mtproto];
  [authProxyPasswordField_ setEnabled:controlsEnabled && !mtproto];
  [authProxySecretField_ setEnabled:controlsEnabled && mtproto];
  [authProxyUserLabel_ setHidden:!enabled || mtproto];
  [authProxyUserField_ setHidden:!enabled || mtproto];
  [authProxyPasswordLabel_ setHidden:!enabled || mtproto];
  [authProxyPasswordField_ setHidden:!enabled || mtproto];
  [authProxySecretLabel_ setHidden:!enabled || !mtproto];
  [authProxySecretField_ setHidden:!enabled || !mtproto];
  [authProxyCheckBtn_ setEnabled:controlsEnabled];
  NSString *state = bridge_ ? [bridge_ authorizationState] : @"";
  BOOL phoneStep = ![state length] || [state isEqualToString:@"authorizationStateWaitPhoneNumber"];
  [self layoutAuthWindowForPhoneStep:phoneStep proxyEnabled:enabled];
}

- (void)loadProxyDefaultsIntoControls {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  NSString *host = [d stringForKey:@"SailplaneProxyHost"];
  [authProxyEnabledBtn_ setState:([d boolForKey:@"SailplaneProxyEnabled"] && [host length]) ? NSOnState : NSOffState];
  NSString *type = [d stringForKey:@"SailplaneProxyType"];
  if (![type length]) type = @"socks5";
  for (NSInteger i = 0; i < [authProxyTypePopup_ numberOfItems]; i++) {
    if ([[[authProxyTypePopup_ itemAtIndex:i] representedObject] isEqualToString:type]) {
      [authProxyTypePopup_ selectItemAtIndex:i];
      break;
    }
  }
  NSString *port = [d stringForKey:@"SailplaneProxyPort"];
  NSString *user = [d stringForKey:@"SailplaneProxyUsername"];
  if (host) [authProxyHostField_ setStringValue:host];
  if (port) [authProxyPortField_ setStringValue:port];
  if (user) [authProxyUserField_ setStringValue:user];
  // Credentials must not be retained in the unencrypted defaults database.
  [d removeObjectForKey:@"SailplaneProxyPassword"];
  [d removeObjectForKey:@"SailplaneProxySecret"];
  [self updateProxyFieldVisibility];
}

- (void)saveProxyDefaults {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  [d setBool:([authProxyEnabledBtn_ state] == NSOnState) forKey:@"SailplaneProxyEnabled"];
  NSString *type = [[authProxyTypePopup_ selectedItem] representedObject];
  if ([type length]) [d setObject:type forKey:@"SailplaneProxyType"];
  [d setObject:[authProxyHostField_ stringValue] forKey:@"SailplaneProxyHost"];
  [d setObject:[authProxyPortField_ stringValue] forKey:@"SailplaneProxyPort"];
  [d setObject:[authProxyUserField_ stringValue] forKey:@"SailplaneProxyUsername"];
  [d removeObjectForKey:@"SailplaneProxyPassword"];
  [d removeObjectForKey:@"SailplaneProxySecret"];
  [d synchronize];
}

- (IBAction)proxySettingsChanged:(id)sender {
  (void)sender;
  [self invalidateVerifiedProxySettings];
  [self updateProxyFieldVisibility];
  [self saveProxyDefaults];
}

- (NSString *)currentProxySettingsSignature {
  NSArray *values = [NSArray arrayWithObjects:
    [[authProxyTypePopup_ selectedItem] representedObject] ? [[authProxyTypePopup_ selectedItem] representedObject] : @"",
    [authProxyHostField_ stringValue] ? [authProxyHostField_ stringValue] : @"",
    [authProxyPortField_ stringValue] ? [authProxyPortField_ stringValue] : @"",
    [authProxyUserField_ stringValue] ? [authProxyUserField_ stringValue] : @"",
    [authProxyPasswordField_ stringValue] ? [authProxyPasswordField_ stringValue] : @"",
    [authProxySecretField_ stringValue] ? [authProxySecretField_ stringValue] : @"", nil];
  return [values componentsJoinedByString:@"\n"];
}

- (void)invalidateVerifiedProxySettings {
  [verifiedAuthProxySettings_ release];
  verifiedAuthProxySettings_ = nil;
}

- (void)controlTextDidChange:(NSNotification *)notification {
  id field = [notification object];
  if (field == authProxyHostField_ || field == authProxyPortField_ ||
      field == authProxyUserField_ || field == authProxyPasswordField_ ||
      field == authProxySecretField_) {
    [self invalidateVerifiedProxySettings];
  }
}

- (IBAction)checkProxyConnection:(id)sender {
  (void)sender;
  if (authRequestInFlight_) {
    [self setAuthWindowStatus:@"A connection check is already in progress."];
    return;
  }
  if ([authProxyEnabledBtn_ state] != NSOnState) {
    [self setAuthWindowStatus:@"Turn on Use proxy before checking the connection."];
    return;
  }
  [pendingAuthPhoneNumber_ release]; pendingAuthPhoneNumber_ = nil;
  authProxyCheckOnly_ = YES;
  if (![self applyProxySettingsBeforeAuth]) {
    authProxyCheckOnly_ = NO;
    return;
  }
  [self setAuthBusy:YES message:@"Checking proxy connection..."];
}

- (BOOL)applyProxySettingsBeforeAuth {
  [self saveProxyDefaults];
  authProxyConfigurationInFlight_ = YES;
  pendingAuthProxyId_ = 0;
  if ([authProxyEnabledBtn_ state] != NSOnState) {
    json p = {{"@type", "disableProxy"}, {"@extra", "sailplane-auth-proxy-disable"}};
    [bridge_ sendJSON:p];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(proxyValidationTimedOut) object:nil];
    [self performSelector:@selector(proxyValidationTimedOut) withObject:nil afterDelay:10.0];
    return YES;
  }

  NSString *host = [[authProxyHostField_ stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *portText = [[authProxyPortField_ stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSScanner *portScanner = [NSScanner scannerWithString:portText];
  int port = 0;
  BOOL validPort = [portText length] && [portScanner scanInt:&port] && [portScanner isAtEnd] && port > 0 && port <= 65535;
  if (![host length] || !validPort) {
    authProxyConfigurationInFlight_ = NO;
    [self setAuthWindowStatus:@"Enter a valid proxy host and port."];
    [authWindow_ makeFirstResponder:![host length] ? (NSResponder *)authProxyHostField_ : (NSResponder *)authProxyPortField_];
    return NO;
  }

  NSString *type = [[authProxyTypePopup_ selectedItem] representedObject];
  NSString *user = [authProxyUserField_ stringValue] ? [authProxyUserField_ stringValue] : @"";
  NSString *pass = [authProxyPasswordField_ stringValue] ? [authProxyPasswordField_ stringValue] : @"";
  NSString *secret = [authProxySecretField_ stringValue] ? [authProxySecretField_ stringValue] : @"";
  json proxyType;
  if ([type isEqualToString:@"http"]) {
    proxyType = {{"@type", "proxyTypeHttp"}, {"username", StdStringFromNSString(user)}, {"password", StdStringFromNSString(pass)}, {"http_only", false}};
  } else if ([type isEqualToString:@"mtproto"]) {
    if (![secret length]) {
      authProxyConfigurationInFlight_ = NO;
      [self setAuthWindowStatus:@"Enter the MTProto secret."];
      [authWindow_ makeFirstResponder:authProxySecretField_];
      return NO;
    }
    proxyType = {{"@type", "proxyTypeMtproto"}, {"secret", StdStringFromNSString(secret)}};
  } else {
    proxyType = {{"@type", "proxyTypeSocks5"}, {"username", StdStringFromNSString(user)}, {"password", StdStringFromNSString(pass)}};
  }
  json proxy = {{"@type", "proxy"}, {"server", StdStringFromNSString(host)}, {"port", port}, {"type", proxyType}};
  json p = {{"@type", "addProxy"}, {"proxy", proxy}, {"enable", true}, {"comment", "Sailplane login"},
            {"@extra", "sailplane-auth-proxy-add"}};
  [bridge_ sendJSON:p];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(proxyValidationTimedOut) object:nil];
  [self performSelector:@selector(proxyValidationTimedOut) withObject:nil afterDelay:20.0];
  return YES;
}

- (void)clearPendingProxyAuthentication {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(proxyValidationTimedOut) object:nil];
  authProxyConfigurationInFlight_ = NO;
  authProxyCheckOnly_ = NO;
  pendingAuthProxyId_ = 0;
  [pendingAuthPhoneNumber_ release]; pendingAuthPhoneNumber_ = nil;
}

- (void)failPendingProxyAuthentication:(NSString *)message {
  if (pendingAuthProxyId_ > 0) {
    json disable = {{"@type", "disableProxy"}};
    json remove = {{"@type", "removeProxy"}, {"proxy_id", pendingAuthProxyId_}};
    [bridge_ sendJSON:disable];
    [bridge_ sendJSON:remove];
  }
  [self invalidateVerifiedProxySettings];
  [self clearPendingProxyAuthentication];
  [self setAuthBusy:NO message:nil];
  [self setAuthWindowStatus:message ? message : @"Proxy connection failed."];
  [authStatusLabel_ setTextColor:[NSColor colorWithCalibratedRed:0.72 green:0.08 blue:0.08 alpha:1.0]];
  [authWindow_ makeFirstResponder:([authProxyEnabledBtn_ state] == NSOnState
    ? (NSResponder *)authProxyHostField_ : (NSResponder *)authPhoneField_)];
}

- (void)completeStandaloneProxyCheck {
  [self invalidateVerifiedProxySettings];
  verifiedAuthProxySettings_ = [[self currentProxySettingsSignature] copy];
  [self clearPendingProxyAuthentication];
  [self setAuthBusy:NO message:nil];
  [self setAuthWindowStatus:@"Proxy connection successful."];
  [authStatusLabel_ setTextColor:[NSColor colorWithCalibratedRed:0.08 green:0.48 blue:0.12 alpha:1.0]];
}

- (void)completePendingPhoneAuthenticationWithProxy:(BOOL)usedProxy {
  NSString *phone = [[pendingAuthPhoneNumber_ copy] autorelease];
  if (usedProxy) {
    [self invalidateVerifiedProxySettings];
    verifiedAuthProxySettings_ = [[self currentProxySettingsSignature] copy];
  }
  [self clearPendingProxyAuthentication];
  if (![phone length] || ![[bridge_ authorizationState] isEqualToString:@"authorizationStateWaitPhoneNumber"]) {
    [self setAuthBusy:NO message:nil];
    [self setAuthWindowStatus:@"Sign-in state changed. Enter your phone number again."];
    return;
  }
  [self setAuthBusy:YES message:(usedProxy ? @"Proxy verified. Sending phone number..." : @"Sending phone number...")];
  [bridge_ submitAuthInput:phone];
}

- (void)proxyValidationTimedOut {
  if (!authProxyConfigurationInFlight_) return;
  [self failPendingProxyAuthentication:@"Proxy test timed out. Check the host and port."];
}

- (BOOL)handleAuthProxyResponseJSON:(const json *)objPtr {
  if (!objPtr || !objPtr->contains("@extra") || !(*objPtr)["@extra"].is_string()) return NO;
  const json &obj = *objPtr;
  NSString *extra = NSStringFromStdString(obj["@extra"].get<std::string>());
  if (![extra hasPrefix:@"sailplane-auth-proxy-"]) return NO;

  NSString *type = obj.contains("@type") && obj["@type"].is_string()
    ? NSStringFromStdString(obj["@type"].get<std::string>()) : @"";
  if ([type isEqualToString:@"error"]) {
    NSString *detail = obj.contains("message") && obj["message"].is_string()
      ? NSStringFromStdString(obj["message"].get<std::string>()) : @"Unknown error";
    [self failPendingProxyAuthentication:[NSString stringWithFormat:@"Proxy connection failed: %@", detail]];
    return YES;
  }

  if ([extra isEqualToString:@"sailplane-auth-proxy-disable"]) {
    [self completePendingPhoneAuthenticationWithProxy:NO];
    return YES;
  }

  if ([extra isEqualToString:@"sailplane-auth-proxy-add"]) {
    if (![type isEqualToString:@"addedProxy"] || !obj.contains("id") || !obj.contains("proxy") || !obj["proxy"].is_object()) {
      [self failPendingProxyAuthentication:@"TDLib returned an invalid proxy response."];
      return YES;
    }
    pendingAuthProxyId_ = obj["id"].get<int>();
    json ping = {{"@type", "pingProxy"}, {"proxy", obj["proxy"]}, {"@extra", "sailplane-auth-proxy-ping"}};
    [self setAuthWindowStatus:@"Testing proxy connection..."];
    [bridge_ sendJSON:ping];
    return YES;
  }

  if ([extra isEqualToString:@"sailplane-auth-proxy-ping"]) {
    if ([type isEqualToString:@"seconds"]) {
      if (authProxyCheckOnly_) [self completeStandaloneProxyCheck];
      else [self completePendingPhoneAuthenticationWithProxy:YES];
    } else {
      [self failPendingProxyAuthentication:@"Proxy test failed."];
    }
    return YES;
  }
  return YES;
}

- (void)configureAuthWindowForState:(NSString *)state {
  BOOL phoneStep = [state isEqualToString:@"authorizationStateWaitPhoneNumber"] || ![state length];
  BOOL passwordStep = [state isEqualToString:@"authorizationStateWaitPassword"];
  if (authTitleLabel_) {
    [authTitleLabel_ setStringValue:(phoneStep ? @"Sign in to Sailplane" : (passwordStep ? @"Two-step verification" : @"Enter login code"))];
  }
  [authCountryLabel_ setHidden:!phoneStep];
  [authCountryPopup_ setHidden:!phoneStep];
  [authPhoneLabel_ setHidden:!phoneStep];
  [authPhoneField_ setHidden:!phoneStep];
  [authCodeLabel_ setHidden:phoneStep];
  [authCodeField_ setHidden:phoneStep];
  [authProxyBox_ setHidden:!phoneStep];
  [authCodeLabel_ setStringValue:(passwordStep ? @"Password:" : @"Authorization Code:")];
  [authSubmitBtn_ setTitle:(phoneStep ? @"Continue" : @"Sign In")];
  [self updateProxyFieldVisibility];
  [self layoutAuthWindowForPhoneStep:phoneStep proxyEnabled:([authProxyEnabledBtn_ state] == NSOnState)];
  [authWindow_ makeFirstResponder:(phoneStep ? (NSResponder *)authPhoneField_ : (NSResponder *)authCodeField_)];
}

- (void)showAuthWindow {
  if (authWindow_) {
    [NSApp activateIgnoringOtherApps:YES];
    [authWindow_ makeKeyAndOrderFront:nil];
    [self configureAuthWindowForState:[bridge_ authorizationState]];
    [authWindow_ orderFrontRegardless];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 560, 390);
  NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];
  frame.origin.x = (screenFrame.size.width - frame.size.width) / 2.0;
  frame.origin.y = (screenFrame.size.height - frame.size.height) / 2.0;

  authWindow_ = [[NSWindow alloc] initWithContentRect:frame styleMask:(NSTitledWindowMask | NSClosableWindowMask) backing:NSBackingStoreBuffered defer:NO];
  [authWindow_ setReleasedWhenClosed:NO];
  [authWindow_ setDelegate:self];
  [authWindow_ setTitle:@"Log In to Sailplane"];
  NSView *cv = [authWindow_ contentView];
  CGFloat w = frame.size.width;

  authIconView_ = [[[NSImageView alloc] initWithFrame:NSMakeRect(28, frame.size.height - 72, 48, 48)] autorelease];
  NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"Sailplane" ofType:@"png"];
  NSImage *icon = iconPath ? [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease] : [NSApp applicationIconImage];
  if (icon) [authIconView_ setImage:icon];
  [cv addSubview:authIconView_];

  authTitleLabel_ = AuthLabel(@"Sign in to Sailplane", NSMakeRect(92, frame.size.height - 50, w - 124, 24), NSLeftTextAlignment, [NSFont boldSystemFontOfSize:18]);
  [cv addSubview:authTitleLabel_];
  authSubtitleLabel_ = AuthLabel(@"Telegram account", NSMakeRect(94, frame.size.height - 72, w - 126, 18), NSLeftTextAlignment, [NSFont systemFontOfSize:12]);
  [authSubtitleLabel_ setTextColor:[NSColor grayColor]];
  [cv addSubview:authSubtitleLabel_];

  CGFloat labelX = 42.0, labelW = 116.0, fieldX = 168.0, fieldW = w - fieldX - 42.0;
  authCountryLabel_ = AuthLabel(@"Country", NSMakeRect(labelX, frame.size.height - 119, labelW, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [cv addSubview:authCountryLabel_];
  authCountryPopup_ = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 124, fieldW, 26) pullsDown:NO] autorelease];
  [authCountryPopup_ setFont:[NSFont systemFontOfSize:12]];
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

  authPhoneLabel_ = AuthLabel(@"Phone", NSMakeRect(labelX, frame.size.height - 157, labelW, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [cv addSubview:authPhoneLabel_];
  authPhoneField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 160, fieldW, 22)] autorelease];
  [authPhoneField_ setFont:[NSFont systemFontOfSize:12]];
  [[authPhoneField_ cell] setPlaceholderString:@"(602) 555-0123"];
  [cv addSubview:authPhoneField_];

  authCodeLabel_ = AuthLabel(@"Code", NSMakeRect(labelX, frame.size.height - 157, labelW, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [cv addSubview:authCodeLabel_];
  authCodeField_ = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(fieldX, frame.size.height - 160, fieldW, 22)] autorelease];
  [authCodeField_ setFont:[NSFont systemFontOfSize:12]];
  [cv addSubview:authCodeField_];

  authProxyBox_ = [[[NSBox alloc] initWithFrame:NSMakeRect(32, 100, w - 64, 134)] autorelease];
  [authProxyBox_ setTitle:@"Proxy"];
  [authProxyBox_ setBoxType:NSBoxPrimary];
  NSView *proxyView = [authProxyBox_ contentView];
  authProxyEnabledBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(14, 86, 112, 22)] autorelease];
  [authProxyEnabledBtn_ setButtonType:NSSwitchButton];
  [authProxyEnabledBtn_ setTitle:@"Use proxy"];
  [authProxyEnabledBtn_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyEnabledBtn_ setTarget:self]; [authProxyEnabledBtn_ setAction:@selector(proxySettingsChanged:)];
  [proxyView addSubview:authProxyEnabledBtn_];

  authProxyCheckBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(132, 84, 138, 26)] autorelease];
  [authProxyCheckBtn_ setTitle:@"Check Connection"];
  [authProxyCheckBtn_ setBezelStyle:NSRoundedBezelStyle];
  [authProxyCheckBtn_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyCheckBtn_ setTarget:self]; [authProxyCheckBtn_ setAction:@selector(checkProxyConnection:)];
  [proxyView addSubview:authProxyCheckBtn_];

  authProxyTypeLabel_ = AuthLabel(@"Type", NSMakeRect(284, 89, 42, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxyTypeLabel_];
  authProxyTypePopup_ = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(336, 84, 130, 26) pullsDown:NO] autorelease];
  [authProxyTypePopup_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyTypePopup_ addItemWithTitle:@"SOCKS5"]; [[authProxyTypePopup_ lastItem] setRepresentedObject:@"socks5"];
  [authProxyTypePopup_ addItemWithTitle:@"HTTP"]; [[authProxyTypePopup_ lastItem] setRepresentedObject:@"http"];
  [authProxyTypePopup_ addItemWithTitle:@"MTProto"]; [[authProxyTypePopup_ lastItem] setRepresentedObject:@"mtproto"];
  [authProxyTypePopup_ setTarget:self]; [authProxyTypePopup_ setAction:@selector(proxySettingsChanged:)];
  [proxyView addSubview:authProxyTypePopup_];

  authProxyHostLabel_ = AuthLabel(@"Host", NSMakeRect(16, 54, 38, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxyHostLabel_];
  authProxyHostField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(64, 51, 274, 22)] autorelease];
  [authProxyHostField_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyHostField_ setDelegate:self];
  [[authProxyHostField_ cell] setPlaceholderString:@"proxy.example.com"];
  [proxyView addSubview:authProxyHostField_];
  authProxyPortLabel_ = AuthLabel(@"Port", NSMakeRect(344, 54, 36, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxyPortLabel_];
  authProxyPortField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(390, 51, 76, 22)] autorelease];
  [authProxyPortField_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyPortField_ setDelegate:self];
  [[authProxyPortField_ cell] setPlaceholderString:@"1080"];
  [proxyView addSubview:authProxyPortField_];

  authProxyUserLabel_ = AuthLabel(@"User", NSMakeRect(16, 20, 38, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxyUserLabel_];
  authProxyUserField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(64, 17, 160, 22)] autorelease];
  [authProxyUserField_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyUserField_ setDelegate:self];
  [proxyView addSubview:authProxyUserField_];
  authProxyPasswordLabel_ = AuthLabel(@"Password", NSMakeRect(230, 20, 70, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxyPasswordLabel_];
  authProxyPasswordField_ = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(310, 17, 156, 22)] autorelease];
  [authProxyPasswordField_ setFont:[NSFont systemFontOfSize:12]];
  [authProxyPasswordField_ setDelegate:self];
  [proxyView addSubview:authProxyPasswordField_];
  authProxySecretLabel_ = AuthLabel(@"Secret", NSMakeRect(16, 20, 38, 17), NSRightTextAlignment, [NSFont systemFontOfSize:12]);
  [proxyView addSubview:authProxySecretLabel_];
  authProxySecretField_ = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(64, 17, 402, 22)] autorelease];
  [authProxySecretField_ setFont:[NSFont systemFontOfSize:12]];
  [authProxySecretField_ setDelegate:self];
  [proxyView addSubview:authProxySecretField_];
  [cv addSubview:authProxyBox_];

  authSubmitBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(w - 138, 28, 96, 28)] autorelease];
  [authSubmitBtn_ setTitle:@"Continue"];
  [authSubmitBtn_ setBezelStyle:NSRoundedBezelStyle];
  [authSubmitBtn_ setTarget:self]; [authSubmitBtn_ setAction:@selector(submitAuth:)];
  [cv addSubview:authSubmitBtn_];
  [authWindow_ setDefaultButtonCell:[authSubmitBtn_ cell]];

  authStatusLabel_ = AuthLabel(@"", NSMakeRect(42, 34, w - 196, 18), NSLeftTextAlignment, [NSFont systemFontOfSize:11]);
  [authStatusLabel_ setTextColor:[NSColor grayColor]];
  [cv addSubview:authStatusLabel_];

  [self loadProxyDefaultsIntoControls];
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
    authIconView_ = nil; authTitleLabel_ = nil; authSubtitleLabel_ = nil; authCountryLabel_ = nil; authCountryPopup_ = nil; authPhoneLabel_ = nil;
    authPhoneField_ = nil; authCodeLabel_ = nil; authCodeField_ = nil; authSubmitBtn_ = nil; authStatusLabel_ = nil;
    authProxyBox_ = nil; authProxyEnabledBtn_ = nil; authProxyCheckBtn_ = nil; authProxyTypeLabel_ = nil; authProxyTypePopup_ = nil;
    authProxyHostLabel_ = nil; authProxyHostField_ = nil; authProxyPortLabel_ = nil; authProxyPortField_ = nil;
    authProxyUserField_ = nil; authProxyPasswordField_ = nil; authProxySecretField_ = nil;
    authProxyUserLabel_ = nil; authProxyPasswordLabel_ = nil; authProxySecretLabel_ = nil;
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
    [pendingAuthPhoneNumber_ release]; pendingAuthPhoneNumber_ = [phone copy];
    authProxyCheckOnly_ = NO;
    if ([authProxyEnabledBtn_ state] == NSOnState && verifiedAuthProxySettings_ &&
        [verifiedAuthProxySettings_ isEqualToString:[self currentProxySettingsSignature]]) {
      [self saveProxyDefaults];
      [authPhoneField_ setStringValue:phone];
      [[NSUserDefaults standardUserDefaults] setObject:phone forKey:@"SailplanePendingPhoneNumber"];
      [[NSUserDefaults standardUserDefaults] synchronize];
      [self completePendingPhoneAuthenticationWithProxy:YES];
      return;
    }
    if (![self applyProxySettingsBeforeAuth]) {
      [pendingAuthPhoneNumber_ release]; pendingAuthPhoneNumber_ = nil;
      return;
    }
    [authPhoneField_ setStringValue:phone];
    [[NSUserDefaults standardUserDefaults] setObject:phone forKey:@"SailplanePendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self setAuthBusy:YES message:([authProxyEnabledBtn_ state] == NSOnState
      ? @"Adding and testing proxy..." : @"Preparing direct connection...")];
    return;
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
  if ([state isEqualToString:@"authorizationStateWaitTdlibParameters"] && ![bridge_ isReady]) {
    // Keep the loader's specific error visible and the form disabled. This is
    // especially important on newer systems that cannot load an older dylib.
    [self showAuthWindow];
    [self setAuthBusy:YES message:nil];
    return;
  }

  BOOL initialState = [state isEqualToString:@"authorizationStateWaitTdlibParameters"] ||
                      [state isEqualToString:@"authorizationStateWaitEncryptionKey"] ||
                      [state isEqualToString:@"authorizationStateWaitPhoneNumber"];
  BOOL interruptedLogin = startupAuthorizationRecovery_ &&
                          [state hasPrefix:@"authorizationStateWait"] &&
                          !initialState;
  if (interruptedLogin) {
    startupAuthorizationRecovery_ = NO;
    resettingInterruptedAuthorization_ = YES;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SailplanePendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegramPPCPendingPhoneNumber"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self showAuthWindow];
    [self configureAuthWindowForState:@"authorizationStateWaitPhoneNumber"];
    [authPhoneField_ setStringValue:@""];
    [self setAuthBusy:YES message:@"Starting a new sign-in..."];
    [bridge_ discardInterruptedAuthorization];
    return;
  }

  if (resettingInterruptedAuthorization_ &&
      ![state isEqualToString:@"authorizationStateClosed"]) {
    [self setAuthBusy:YES message:@"Starting a new sign-in..."];
    return;
  }

  if ([state isEqualToString:@"authorizationStateWaitPhoneNumber"] ||
      [state isEqualToString:@"authorizationStateReady"]) {
    startupAuthorizationRecovery_ = NO;
  }

  BOOL loggingOut = [state isEqualToString:@"authorizationStateLoggingOut"] ||
                    [state isEqualToString:@"authorizationStateClosing"];
  [self setAuthBusy:loggingOut message:(loggingOut ? @"Logging out..." : nil)];

  if ([state isEqualToString:@"authorizationStateWaitTdlibParameters"]) {
    [self showAuthWindow];
    if (!tdlibConfigured_) {
      tdlibConfigured_ = YES;
      [self setStatusText:@"Configuring TDLib..."];
      [bridge_ submitAuthInput:@""];
    }
  } else if ([state isEqualToString:@"authorizationStateWaitEncryptionKey"]) {
    [self showAuthWindow];
    [self setStatusText:@"Opening local database..."];
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
    logoutInProgress_ = NO;
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
  } else if (loggingOut) {
    [self setAuthWindowStatus:@"Logging out..."];
  } else if ([state isEqualToString:@"authorizationStateClosed"]) {
    BOOL discardedInterruptedLogin = resettingInterruptedAuthorization_;
    resettingInterruptedAuthorization_ = NO;
    tdlibConfigured_ = NO;
    [self resetLocalSessionStateForLogout];
    [self showAuthWindow];
    [self configureAuthWindowForState:@"authorizationStateWaitPhoneNumber"];
    [authPhoneField_ setStringValue:@""];
    [self setAuthWindowStatus:(discardedInterruptedLogin
      ? @"Enter your phone number to start a new sign-in."
      : @"Logged out. Preparing a new login session...")];
    [bridge_ restartClientForLogin];
  } else {
    [self setStatusText:state];
  }
}

@end
