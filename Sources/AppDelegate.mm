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

@implementation AppDelegate

- (void)createMenus {
  NSMenu *mb = [NSApp mainMenu];
  if (!mb) {
    mb = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];
    [NSApp setMainMenu:mb];
  } else {
    while ([mb numberOfItems] > 1) [mb removeItemAtIndex:1];
  }

  NSMenuItem *ami = nil;
  if ([mb numberOfItems] > 0) {
    ami = [mb itemAtIndex:0];
    [ami setTitle:@"TelegramPPC"];
  } else {
    ami = [[[NSMenuItem alloc] initWithTitle:@"TelegramPPC" action:NULL keyEquivalent:@""] autorelease];
    [mb addItem:ami];
  }
  NSMenu *am = [[[NSMenu alloc] initWithTitle:@"TelegramPPC"] autorelease];
  [ami setSubmenu:am];
  SEL setAppleMenuSel = NSSelectorFromString(@"setAppleMenu:");
  if ([NSApp respondsToSelector:setAppleMenuSel]) [NSApp performSelector:setAppleMenuSel withObject:am];
  [am addItemWithTitle:@"About TelegramPPC" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
  [am addItem:[NSMenuItem separatorItem]];
  [am addItemWithTitle:@"Preferences..." action:nil keyEquivalent:@","];
  [am addItem:[NSMenuItem separatorItem]];
  NSMenuItem *services = [[[NSMenuItem alloc] initWithTitle:@"Services" action:NULL keyEquivalent:@""] autorelease];
  NSMenu *servicesMenu = [[[NSMenu alloc] initWithTitle:@"Services"] autorelease];
  [services setSubmenu:servicesMenu];
  [am addItem:services];
  [NSApp setServicesMenu:servicesMenu];
  [am addItem:[NSMenuItem separatorItem]];
  [am addItemWithTitle:@"Hide TelegramPPC" action:@selector(hide:) keyEquivalent:@"h"];
  NSMenuItem *hideOthers = [am addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
  [hideOthers setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
  [am addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
  [am addItem:[NSMenuItem separatorItem]];
  [am addItemWithTitle:@"Quit TelegramPPC" action:@selector(terminate:) keyEquivalent:@"q"];

  NSMenuItem *fmi = [[[NSMenuItem alloc] initWithTitle:@"File" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:fmi];
  NSMenu *fm = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
  [fmi setSubmenu:fm];
  [fm addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];

  NSMenuItem *emi = [[[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:emi];
  NSMenu *em = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
  [emi setSubmenu:em];
  [em addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
  [em addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
  [em addItem:[NSMenuItem separatorItem]];
  [em addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  [em addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  [em addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  [em addItem:[NSMenuItem separatorItem]];
  [em addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];

  NSMenuItem *vmi = [[[NSMenuItem alloc] initWithTitle:@"View" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:vmi];
  NSMenu *vm = [[[NSMenu alloc] initWithTitle:@"View"] autorelease];
  [vmi setSubmenu:vm];
  [vm addItemWithTitle:@"Show Toolbar" action:@selector(toggleToolbarShown:) keyEquivalent:@""];
  [vm addItemWithTitle:@"Customize Toolbar..." action:@selector(runToolbarCustomizationPalette:) keyEquivalent:@""];
  [vm addItem:[NSMenuItem separatorItem]];
  [vm addItemWithTitle:@"Search Chats" action:@selector(focusSearch:) keyEquivalent:@"f"];

  NSMenuItem *cmi = [[[NSMenuItem alloc] initWithTitle:@"Chat" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:cmi];
  NSMenu *cm = [[[NSMenu alloc] initWithTitle:@"Chat"] autorelease];
  [cmi setSubmenu:cm];
  [cm addItemWithTitle:@"Refresh Chats" action:@selector(refreshChatsAction:) keyEquivalent:@"r"];
  [cm addItemWithTitle:@"Call" action:@selector(callButtonClicked:) keyEquivalent:@"l"];

  NSMenuItem *mmi = [[[NSMenuItem alloc] initWithTitle:@"Message" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:mmi];
  NSMenu *mm = [[[NSMenu alloc] initWithTitle:@"Message"] autorelease];
  [mmi setSubmenu:mm];
  [mm addItemWithTitle:@"Send" action:@selector(sendCurrentMessage:) keyEquivalent:@"\r"];
  [mm addItemWithTitle:@"Attach File..." action:@selector(attachFile:) keyEquivalent:@"u"];

  NSMenuItem *wmi = [[[NSMenuItem alloc] initWithTitle:@"Window" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:wmi];
  NSMenu *wm = [[[NSMenu alloc] initWithTitle:@"Window"] autorelease];
  [wmi setSubmenu:wm];
  [wm addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
  [wm addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
  [NSApp setWindowsMenu:wm];

  NSMenuItem *hmi = [[[NSMenuItem alloc] initWithTitle:@"Help" action:NULL keyEquivalent:@""] autorelease];
  [mb addItem:hmi];
  NSMenu *hm = [[[NSMenu alloc] initWithTitle:@"Help"] autorelease];
  [hmi setSubmenu:hm];
  [hm addItemWithTitle:@"TelegramPPC Help" action:nil keyEquivalent:@""];
}

- (id)init {
  self = [super init];
  if (self) {
    chatIds_ = [[NSMutableArray alloc] init];
    chatsById_ = [[NSMutableDictionary alloc] init];
    messagesByChatId_ = [[NSMutableDictionary alloc] init];
    messageCellCache_ = [[NSMutableDictionary alloc] init];
    usersById_ = [[NSMutableDictionary alloc] init];
    filePaths_ = [[NSMutableDictionary alloc] init];
    pendingDownloads_ = [[NSMutableSet alloc] init];
    expandedMessages_ = [[NSMutableSet alloc] init];
    chatFilter_ = nil;
    selectedChatId_ = 0; authRequestInFlight_ = NO; meUserId_ = 0;
    expectingGetMe_ = NO; tdlibConfigured_ = NO; meUser_ = nil; profilePhotoFileId_ = 0; profilePhotoPath_ = nil;
    chatRefreshScheduled_ = NO; messageRefreshScheduled_ = NO;
    pendingMessageHeightInvalidation_ = YES; lastMessageTableWidth_ = 0.0;
    authWindow_ = nil; mainWindow_ = nil;
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self stopInlineVideoPlayer];
  [bridge_ release]; [chatIds_ release]; [chatsById_ release]; [messagesByChatId_ release]; [messageCellCache_ release];
  [usersById_ release]; [filePaths_ release]; [pendingDownloads_ release];
  [expandedMessages_ release];
  [chatFilter_ release];
  [meUser_ release]; [profilePhotoPath_ release];
  authWindow_ = nil; mainWindow_ = nil;
  [super dealloc];
}

- (void)setStatusText:(NSString *)t {
  if (mainWindow_ && statusLabel_) [statusLabel_ setStringValue:t ? t : @""];
  if (authWindow_ && authStatusLabel_) [authStatusLabel_ setStringValue:t ? t : @""];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  (void)toolbar;
  return [NSArray arrayWithObjects:@"Profile", @"Refresh", @"Search", NSToolbarFlexibleSpaceItemIdentifier, @"Call", NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
  (void)toolbar;
  return [NSArray arrayWithObjects:@"Profile", @"Refresh", NSToolbarFlexibleSpaceItemIdentifier, @"Search", @"Call", nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  (void)toolbar;
  return [NSArray array];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag {
  (void)toolbar; (void)flag;
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
  if ([identifier isEqualToString:@"Refresh"]) {
    [item setLabel:@"Refresh"];
    [item setPaletteLabel:@"Refresh Chats"];
    [item setToolTip:@"Refresh chats"];
    [item setTarget:self];
    [item setAction:@selector(refreshChatsAction:)];
    NSImage *img = ToolbarIconImage(@"refresh_24.png", 18.0);
    if (img) [item setImage:img];
  } else if ([identifier isEqualToString:@"Search"]) {
    if (!searchField_) {
      searchField_ = [[NSSearchField alloc] initWithFrame:NSMakeRect(0, 0, 220, 22)];
      [searchField_ setTarget:self];
      [searchField_ setAction:@selector(searchChanged:)];
      [searchField_ setToolTip:@"Search chats"];
      [[searchField_ cell] setPlaceholderString:@"Search"];
    }
    [item setLabel:@"Search"];
    [item setPaletteLabel:@"Search Chats"];
    [item setView:searchField_];
    [item setMinSize:NSMakeSize(160, 22)];
    [item setMaxSize:NSMakeSize(260, 22)];
  } else if ([identifier isEqualToString:@"Call"]) {
    if (!callButton_) {
      callButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 34, 28)];
      [callButton_ setButtonType:NSMomentaryPushInButton];
      [callButton_ setBezelStyle:NSRoundedBezelStyle];
      [callButton_ setTitle:@""];
      [callButton_ setImage:ToolbarIconImage(@"phone_24.png", 18.0)];
      [callButton_ setImagePosition:NSImageOnly];
      [callButton_ setTarget:self]; [callButton_ setAction:@selector(callButtonClicked:)];
      [callButton_ setToolTip:@"Start a call with the selected chat"];
      [callButton_ setEnabled:NO];
    }
    [item setLabel:@"Call"];
    [item setPaletteLabel:@"Call"];
    [item setView:callButton_];
    [item setMinSize:NSMakeSize(34, 28)];
    [item setMaxSize:NSMakeSize(34, 28)];
  } else if ([identifier isEqualToString:@"Profile"]) {
    if (!profileButton_) {
      profileButton_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 32, 32)];
      [profileButton_ setButtonType:NSMomentaryChangeButton];
      [profileButton_ setBordered:NO];
      [profileButton_ setImagePosition:NSImageOnly];
      [profileButton_ setTarget:self]; [profileButton_ setAction:@selector(profileClicked:)];
      [profileButton_ setToolTip:@"Account actions"];
      [self updateProfilePhoto];
    }
    [item setLabel:@"Account"];
    [item setPaletteLabel:@"Account"];
    [item setView:profileButton_];
    [item setMinSize:NSMakeSize(32, 32)];
    [item setMaxSize:NSMakeSize(32, 32)];
  } else {
    return nil;
  }
  return item;
}

- (void)updateMainLayout {
  if (mainWindow_ && statusBar_ && mainSplitView_) {
    NSRect cb = [[mainWindow_ contentView] bounds];
    CGFloat statusH = 22.0;
    [statusBar_ setFrame:NSMakeRect(0, 0, cb.size.width, statusH)];
    [mainSplitView_ setFrame:NSMakeRect(0, statusH, cb.size.width, cb.size.height - statusH)];
    NSArray *splitSubviews = [mainSplitView_ subviews];
    if ([splitSubviews count] >= 2) {
      CGFloat leftW = 284.0;
      CGFloat dividerW = [mainSplitView_ dividerThickness];
      NSRect sb = [mainSplitView_ bounds];
      if (leftW > sb.size.width - 240.0) leftW = sb.size.width - 240.0;
      if (leftW < 180.0) leftW = 180.0;
      NSView *leftView = [splitSubviews objectAtIndex:0];
      NSView *rightView = [splitSubviews objectAtIndex:1];
      [leftView setFrame:NSMakeRect(0, 0, leftW, sb.size.height)];
      [rightView setFrame:NSMakeRect(leftW + dividerW, 0, sb.size.width - leftW - dividerW, sb.size.height)];
    }
    if (statusLabel_) [statusLabel_ setFrame:NSMakeRect(10, 2, cb.size.width - 20, 18)];
  }
  if (!conversationView_) return;
  NSRect b = [conversationView_ bounds];
  CGFloat barH = 44.0;
  CGFloat replyH = (replyBarContainer_ && ![replyBarContainer_ isHidden]) ? 24.0 : 0.0;
  CGFloat callH = (callBar_ && ![callBar_ isHidden]) ? 32.0 : 0.0;

  if (composeBar_) [composeBar_ setFrame:NSMakeRect(0, 0, b.size.width, barH)];
  if (attachButton_) [attachButton_ setFrame:NSMakeRect(10, 10, 78, 23)];
  if (sendButton_) [sendButton_ setFrame:NSMakeRect(b.size.width - 82, 10, 72, 23)];
  if (composeField_) [composeField_ setFrame:NSMakeRect(98, 10, b.size.width - 190, 22)];

  if (replyBarContainer_) [replyBarContainer_ setFrame:NSMakeRect(0, barH, b.size.width, replyH)];
  if (cancelReplyBtn_) [cancelReplyBtn_ setFrame:NSMakeRect(10, 1, 70, 22)];
  if (replyBarLabel_) [replyBarLabel_ setFrame:NSMakeRect(90, 3, b.size.width - 100, 18)];

  if (callBar_) [callBar_ setFrame:NSMakeRect(0, b.size.height - callH, b.size.width, callH)];
  if (callBarLabel_) [callBarLabel_ setFrame:NSMakeRect(10, 6, b.size.width - 230, 20)];
  if (callAcceptBtn_) [callAcceptBtn_ setFrame:NSMakeRect(b.size.width - 210, 4, 70, 23)];
  if (callDeclineBtn_) [callDeclineBtn_ setFrame:NSMakeRect(b.size.width - 132, 4, 70, 23)];
  if (callEndBtn_) [callEndBtn_ setFrame:NSMakeRect(b.size.width - 90, 4, 80, 23)];

  CGFloat messageY = barH + replyH;
  CGFloat messageH = b.size.height - messageY - callH;
  if (messageH < 80.0) messageH = 80.0;
  if (messageScrollView_) [messageScrollView_ setFrame:NSMakeRect(0, messageY, b.size.width, messageH)];
  if (messageTable_) {
    NSRect docBounds = [[messageScrollView_ contentView] bounds];
    CGFloat tableW = docBounds.size.width > 0.0 ? docBounds.size.width : b.size.width;
    CGFloat tableH = docBounds.size.height > 0.0 ? docBounds.size.height : messageH;
    if ([messageTable_ frame].size.height > tableH) tableH = [messageTable_ frame].size.height;
    [messageTable_ setFrameSize:NSMakeSize(tableW, tableH)];
    if ([[messageTable_ tableColumns] count] > 0) {
      [[[messageTable_ tableColumns] objectAtIndex:0] setWidth:tableW];
    }
    CGFloat delta = tableW - lastMessageTableWidth_;
    if (delta < 0.0) delta = -delta;
    if (delta > 0.5) {
      lastMessageTableWidth_ = tableW;
      pendingMessageHeightInvalidation_ = YES;
    }
    if (pendingMessageHeightInvalidation_) {
      [messageCellCache_ removeAllObjects];
      NSInteger rows = [messageTable_ numberOfRows];
      if (rows > 0) {
        [messageTable_ reloadData];
      }
      pendingMessageHeightInvalidation_ = NO;
    }
    [messageTable_ setNeedsDisplay:YES];
  }
  if ([[chatTable_ tableColumns] count] > 0) [[[chatTable_ tableColumns] objectAtIndex:0] setWidth:[[chatTable_ enclosingScrollView] bounds].size.width - 18.0];
}

- (void)showMainWindow {
  if (mainWindow_) {
    [mainWindow_ makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(100, 100, 1100, 720);
  mainWindow_ = [[NSWindow alloc] initWithContentRect:frame styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask) backing:NSBackingStoreBuffered defer:NO];
  [mainWindow_ setTitle:@"TelegramPPC"];
  [mainWindow_ setDelegate:self];

  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"TelegramPPCToolbarPolished2"] autorelease];
  [toolbar setDelegate:self];
  [toolbar setAllowsUserCustomization:YES];
  [toolbar setAutosavesConfiguration:NO];
  [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
  [mainWindow_ setToolbar:toolbar];

  NSView *cv = [mainWindow_ contentView];
  CGFloat w = frame.size.width, h = frame.size.height;

  statusBar_ = [[[FrameBarView alloc] initWithFrame:NSMakeRect(0, 0, w, 22)] autorelease];
  [statusBar_ setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [cv addSubview:statusBar_];
  statusLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(10, 2, w - 20, 18)] autorelease];
  [statusLabel_ setBezeled:NO]; [statusLabel_ setDrawsBackground:NO]; [statusLabel_ setEditable:NO]; [statusLabel_ setSelectable:NO];
  [statusLabel_ setFont:[NSFont systemFontOfSize:11]];
  [statusLabel_ setTextColor:[NSColor colorWithCalibratedWhite:0.25 alpha:1.0]];
  [statusLabel_ setStringValue:@""];
  [statusBar_ addSubview:statusLabel_];

  mainSplitView_ = [[[NSSplitView alloc] initWithFrame:NSMakeRect(0, 22, w, h - 22)] autorelease];
  [mainSplitView_ setVertical:YES];
  [mainSplitView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [cv addSubview:mainSplitView_];

  NSView *sourceView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 284, h - 22)] autorelease];
  [sourceView setAutoresizingMask:NSViewHeightSizable];
  conversationView_ = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, w - 284, h - 22)] autorelease];
  [conversationView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [mainSplitView_ addSubview:sourceView];
  [mainSplitView_ addSubview:conversationView_];

  chatScrollView_ = [[[NSScrollView alloc] initWithFrame:[sourceView bounds]] autorelease];
  [chatScrollView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [chatScrollView_ setHasVerticalScroller:YES];
  [chatScrollView_ setBorderType:NSNoBorder];
  chatTable_ = [[[NSTableView alloc] initWithFrame:[[chatScrollView_ contentView] bounds]] autorelease];
  NSTableColumn *cc = [[[NSTableColumn alloc] initWithIdentifier:@"chat"] autorelease];
  [cc setWidth:266];
  [cc setDataCell:[[[ChatCell alloc] init] autorelease]];
  [chatTable_ addTableColumn:cc];
  [chatTable_ setDelegate:self]; [chatTable_ setDataSource:self];
  [chatTable_ setRowHeight:44];
  [chatTable_ setUsesAlternatingRowBackgroundColors:NO];
  [chatTable_ setGridStyleMask:NSTableViewGridNone];
  [chatTable_ setBackgroundColor:[NSColor colorWithCalibratedRed:0.83 green:0.88 blue:0.94 alpha:1.0]];
  [chatTable_ setHeaderView:nil];
  [chatScrollView_ setDocumentView:chatTable_];
  [sourceView addSubview:chatScrollView_];

  callBar_ = [[[FrameBarView alloc] initWithFrame:NSMakeRect(0, h - 32, w - 284, 32)] autorelease];
  [callBar_ setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [callBar_ setHidden:YES];
  [conversationView_ addSubview:callBar_];
  callBarLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(10, 6, callBar_.frame.size.width - 230, 20)] autorelease];
  [callBarLabel_ setBezeled:NO]; [callBarLabel_ setDrawsBackground:NO]; [callBarLabel_ setEditable:NO]; [callBarLabel_ setSelectable:NO];
  [callBarLabel_ setFont:[NSFont boldSystemFontOfSize:12]];
  [callBarLabel_ setTextColor:[NSColor blackColor]];
  [callBar_ addSubview:callBarLabel_];
  callAcceptBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(callBar_.frame.size.width - 210, 4, 70, 23)] autorelease];
  [callAcceptBtn_ setTitle:@"Accept"]; [callAcceptBtn_ setButtonType:NSMomentaryPushInButton];
  [callAcceptBtn_ setBezelStyle:NSRoundedBezelStyle]; [callAcceptBtn_ setFont:[NSFont systemFontOfSize:11]];
  [callAcceptBtn_ setTarget:self]; [callAcceptBtn_ setAction:@selector(acceptCallAction:)];
  [callBar_ addSubview:callAcceptBtn_];
  callDeclineBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(callBar_.frame.size.width - 132, 4, 70, 23)] autorelease];
  [callDeclineBtn_ setTitle:@"Decline"]; [callDeclineBtn_ setButtonType:NSMomentaryPushInButton];
  [callDeclineBtn_ setBezelStyle:NSRoundedBezelStyle]; [callDeclineBtn_ setFont:[NSFont systemFontOfSize:11]];
  [callDeclineBtn_ setTarget:self]; [callDeclineBtn_ setAction:@selector(declineCallAction:)];
  [callBar_ addSubview:callDeclineBtn_];
  callEndBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(callBar_.frame.size.width - 90, 4, 80, 23)] autorelease];
  [callEndBtn_ setTitle:@"End Call"]; [callEndBtn_ setButtonType:NSMomentaryPushInButton];
  [callEndBtn_ setBezelStyle:NSRoundedBezelStyle]; [callEndBtn_ setFont:[NSFont systemFontOfSize:11]];
  [callEndBtn_ setTarget:self]; [callEndBtn_ setAction:@selector(endCallAction:)];
  [callEndBtn_ setHidden:YES];
  [callBar_ addSubview:callEndBtn_];

  messageScrollView_ = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 44, w - 284, h - 44)] autorelease];
  [messageScrollView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [messageScrollView_ setHasVerticalScroller:YES];
  [messageScrollView_ setBorderType:NSNoBorder];
  messageTable_ = [[[NSTableView alloc] initWithFrame:[[messageScrollView_ contentView] bounds]] autorelease];
  [messageTable_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  NSTableColumn *mc = [[[NSTableColumn alloc] initWithIdentifier:@"message"] autorelease];
  [mc setWidth:w - 302]; [[mc headerCell] setStringValue:@"Messages"]; [messageTable_ addTableColumn:mc];
  MessageCell *mcell = [[[MessageCell alloc] init] autorelease];
  [mc setDataCell:mcell];
  [messageTable_ setDelegate:self]; [messageTable_ setDataSource:self];
  [messageTable_ setTarget:self]; [messageTable_ setAction:@selector(messageTableClicked:)];
  [messageTable_ setHeaderView:nil];
  [messageTable_ setGridStyleMask:NSTableViewGridNone];
  [messageTable_ setBackgroundColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
  [[messageScrollView_ contentView] setPostsBoundsChangedNotifications:YES];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageScrollViewBoundsChanged:) name:NSViewBoundsDidChangeNotification object:[messageScrollView_ contentView]];
  [messageScrollView_ setDocumentView:messageTable_];
  [conversationView_ addSubview:messageScrollView_];

  replyBarContainer_ = [[[FrameBarView alloc] initWithFrame:NSMakeRect(0, 44, w - 284, 24)] autorelease];
  [replyBarContainer_ setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
  [replyBarContainer_ setHidden:YES];
  [conversationView_ addSubview:replyBarContainer_];
  cancelReplyBtn_ = [[[NSButton alloc] initWithFrame:NSMakeRect(10, 1, 70, 22)] autorelease];
  [cancelReplyBtn_ setTitle:@"Cancel"];
  [cancelReplyBtn_ setButtonType:NSMomentaryPushInButton];
  [cancelReplyBtn_ setBezelStyle:NSRoundedBezelStyle];
  [cancelReplyBtn_ setFont:[NSFont systemFontOfSize:11]];
  [cancelReplyBtn_ setTarget:self]; [cancelReplyBtn_ setAction:@selector(cancelReplyEdit)];
  [replyBarContainer_ addSubview:cancelReplyBtn_];
  replyBarLabel_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(90, 3, replyBarContainer_.frame.size.width - 100, 18)] autorelease];
  [replyBarLabel_ setBezeled:NO]; [replyBarLabel_ setDrawsBackground:NO]; [replyBarLabel_ setEditable:NO]; [replyBarLabel_ setSelectable:NO];
  [replyBarLabel_ setFont:[NSFont systemFontOfSize:10]];
  [replyBarLabel_ setTextColor:[NSColor grayColor]];
  [replyBarContainer_ addSubview:replyBarLabel_];

  composeBar_ = [[[FrameBarView alloc] initWithFrame:NSMakeRect(0, 0, w - 284, 44)] autorelease];
  [composeBar_ setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
  [conversationView_ addSubview:composeBar_];

  attachButton_ = [[[NSButton alloc] initWithFrame:NSMakeRect(10, 10, 78, 23)] autorelease];
  [attachButton_ setButtonType:NSMomentaryPushInButton];
  [attachButton_ setBezelStyle:NSRoundedBezelStyle];
  [attachButton_ setTitle:@"Attach"];
  [attachButton_ setFont:[NSFont systemFontOfSize:11]];
  [attachButton_ setToolTip:@"Attach a file"];
  [attachButton_ setTarget:self]; [attachButton_ setAction:@selector(attachFile:)];
  [composeBar_ addSubview:attachButton_];

  composeField_ = [[[NSTextField alloc] initWithFrame:NSMakeRect(98, 10, w - 474, 22)] autorelease];
  [composeField_ setBezeled:YES];
  [composeField_ setBezelStyle:NSTextFieldRoundedBezel];
  [composeField_ setFont:[NSFont systemFontOfSize:12]];
  [composeBar_ addSubview:composeField_];

  sendButton_ = [[[NSButton alloc] initWithFrame:NSMakeRect(w - 366, 10, 72, 23)] autorelease];
  [sendButton_ setButtonType:NSMomentaryPushInButton];
  [sendButton_ setBezelStyle:NSRoundedBezelStyle];
  [sendButton_ setTitle:@"Send"];
  [sendButton_ setFont:[NSFont systemFontOfSize:11]];
  [sendButton_ setToolTip:@"Send message"];
  [sendButton_ setTarget:self]; [sendButton_ setAction:@selector(sendCurrentMessage:)];
  [composeBar_ addSubview:sendButton_];

  [self updateMainLayout];
  [mainWindow_ makeKeyAndOrderFront:nil];
  [self updateMainLayout];
  [self performSelector:@selector(updateMainLayout) withObject:nil afterDelay:0.0];
}

- (void)updateProfilePhoto {
  if (!profileButton_) return;
  if (profilePhotoPath_) {
    NSImage *img = [[[NSImage alloc] initWithContentsOfFile:profilePhotoPath_] autorelease];
    NSSize imgSize = img ? [img size] : NSZeroSize;
    if (img && imgSize.width > 0.0 && imgSize.height > 0.0) {
      NSImage *scaled = [[[NSImage alloc] initWithSize:NSMakeSize(32, 32)] autorelease];
      [scaled lockFocus];
      [[NSColor clearColor] setFill];
      NSRectFill(NSMakeRect(0, 0, 32, 32));
      NSBezierPath *clip = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, 32, 32)];
      [NSGraphicsContext saveGraphicsState];
      [clip addClip];
      [img drawInRect:NSMakeRect(0, 0, 32, 32) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
      [NSGraphicsContext restoreGraphicsState];
      [[NSColor colorWithCalibratedWhite:1.0 alpha:0.85] setStroke];
      [clip setLineWidth:2.0];
      [clip stroke];
      [[NSColor colorWithCalibratedWhite:0.48 alpha:1.0] setStroke];
      [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(NSMakeRect(0, 0, 32, 32), 0.5, 0.5)] stroke];
      [scaled unlockFocus];
      [profileButton_ setImage:scaled];
      [profileButton_ setNeedsDisplay:YES];
      return;
    }
  }
  // Default: first letter of first name in a circle
  NSString *initial = @"?";
  if (meUser_) {
    NSString *fn = StringOrEmpty([meUser_ objectForKey:@"first_name"]);
    if ([fn length]) initial = [fn substringToIndex:1];
  }
  // Draw a simple initial image
  NSImage *defImg = [[[NSImage alloc] initWithSize:NSMakeSize(32, 32)] autorelease];
  [defImg lockFocus];
  [[NSColor colorWithCalibratedRed:0.46 green:0.62 blue:0.78 alpha:1.0] setFill];
  NSBezierPath *defCircle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, 32, 32)];
  [defCircle fill];
  NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:15], NSFontAttributeName, [NSColor whiteColor], NSForegroundColorAttributeName, nil];
  NSSize sz = [initial sizeWithAttributes:attrs];
  [initial drawAtPoint:NSMakePoint((32 - sz.width) / 2, (32 - sz.height) / 2) withAttributes:attrs];
  [[NSColor colorWithCalibratedWhite:1.0 alpha:0.85] setStroke];
  [defCircle setLineWidth:2.0];
  [defCircle stroke];
  [[NSColor colorWithCalibratedWhite:0.48 alpha:1.0] setStroke];
  [[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(NSMakeRect(0, 0, 32, 32), 0.5, 0.5)] stroke];
  [defImg unlockFocus];
  [profileButton_ setImage:defImg];
  [profileButton_ setNeedsDisplay:YES];
}

- (void)requestProfilePhotoDownload {
  if (profilePhotoFileId_ == 0) return;
  NSNumber *fid = [NSNumber numberWithLongLong:profilePhotoFileId_];
  if ([pendingDownloads_ containsObject:fid]) return;
  NSString *existing = [filePaths_ objectForKey:fid];
  if ([existing length] > 0) {
    if (profilePhotoPath_) [profilePhotoPath_ release];
    profilePhotoPath_ = [existing copy];
    [self updateProfilePhoto];
    return;
  }
  [pendingDownloads_ addObject:fid];
  [bridge_ downloadFile:profilePhotoFileId_ priority:32];
}

- (void)profileClicked:(id)sender {
  (void)sender;
  NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Profile"] autorelease];
  [menu addItemWithTitle:@"Account" action:nil keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Logout" action:@selector(logout:) keyEquivalent:@""];
  [NSMenu popUpContextMenu:menu withEvent:[NSApp currentEvent] forView:profileButton_];
}

- (IBAction)refreshChatsAction:(id)sender {
  (void)sender;
  [bridge_ loadChats];
  [self refreshChats];
  [self setStatusText:@"Refreshing chats..."];
}

- (IBAction)searchChanged:(id)sender {
  (void)sender;
  [chatFilter_ release];
  chatFilter_ = [[[searchField_ stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
  if (![chatFilter_ length]) { [chatFilter_ release]; chatFilter_ = nil; }
  [self refreshChats];
}

- (IBAction)focusSearch:(id)sender {
  (void)sender;
  if (mainWindow_ && searchField_) [mainWindow_ makeFirstResponder:searchField_];
}

- (void)messageScrollViewBoundsChanged:(NSNotification *)note {
  (void)note;
  [self updateInlineVideoVisibility];
}

- (void)windowDidResize:(NSNotification *)note {
  (void)note;
  [self updateMainLayout];
  [self updateInlineVideoVisibility];
}

- (void)logout:(id)sender {
  (void)sender;
  [self stopInlineVideoPlayer];
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performScheduledChatRefresh) object:nil];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performScheduledMessageRefresh) object:nil];
  json p = {{"@type", "logOut"}};
  [bridge_ sendJSON:p];
  // Close main window
  if (mainWindow_) { [mainWindow_ orderOut:nil]; [mainWindow_ release]; mainWindow_ = nil; }
  statusLabel_ = nil; statusBar_ = nil; mainSplitView_ = nil; conversationView_ = nil; chatScrollView_ = nil; messageScrollView_ = nil; composeBar_ = nil;
  chatTable_ = nil; messageTable_ = nil; composeField_ = nil; sendButton_ = nil; attachButton_ = nil; profileButton_ = nil; searchField_ = nil;
  replyBarLabel_ = nil; cancelReplyBtn_ = nil; replyBarContainer_ = nil;
  callButton_ = nil; callBar_ = nil; callBarLabel_ = nil; callAcceptBtn_ = nil; callDeclineBtn_ = nil; callEndBtn_ = nil;
  [chatFilter_ release]; chatFilter_ = nil;
  [chatIds_ removeAllObjects]; [chatsById_ removeAllObjects]; [messagesByChatId_ removeAllObjects];
  [messageCellCache_ removeAllObjects];
  [usersById_ removeAllObjects]; [filePaths_ removeAllObjects]; [pendingDownloads_ removeAllObjects];
  selectedChatId_ = 0; meUserId_ = 0; expectingGetMe_ = NO; tdlibConfigured_ = NO;
  chatRefreshScheduled_ = NO; messageRefreshScheduled_ = NO;
  pendingMessageHeightInvalidation_ = YES; lastMessageTableWidth_ = 0.0;
  [meUser_ release]; meUser_ = nil;
  [profilePhotoPath_ release]; profilePhotoPath_ = nil; profilePhotoFileId_ = 0;
  [self setStatusText:@"Logged out. Waiting for new login..."];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
  (void)note;
  NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"TelegramPPC" ofType:@"png"];
  if (iconPath) {
    NSImage *appIcon = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
    if (appIcon) [NSApp setApplicationIconImage:appIcon];
  }

  // Load VOIP backend
  NSArray *voipPaths = [NSArray arrayWithObjects:
    [[[NSBundle mainBundle] privateFrameworksPath] stringByAppendingPathComponent:@"libppcvoip.dylib"],
    nil];
  for (NSUInteger i = 0; i < [voipPaths count]; i++) {
    voipHandle_ = dlopen([[voipPaths objectAtIndex:i] fileSystemRepresentation], RTLD_NOW | RTLD_LOCAL);
    if (voipHandle_) break;
  }
  if (voipHandle_) {
    voipCreate_ = reinterpret_cast<void *(*)(int, const char *, int, const unsigned char *, int)>(dlsym(voipHandle_, "ppc_voip_create"));
    voipDestroy_ = reinterpret_cast<void (*)(void *)>(dlsym(voipHandle_, "ppc_voip_destroy"));
  }

  bridge_ = [[TelegramBridge alloc] initWithDelegate:self];
  [bridge_ start];
  [NSTimer scheduledTimerWithTimeInterval:0.10 target:bridge_ selector:@selector(poll) userInfo:nil repeats:YES];
  [bridge_ poll];
  [self performSelector:@selector(resumeAuthorizationFlowAfterLaunch) withObject:nil afterDelay:0.25];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)s {
  (void)s; return YES;
}

- (IBAction)sendCurrentMessage:(id)sender {
  (void)sender;
  if (selectedChatId_ == 0) { [self setStatusText:@"Select a chat first."]; return; }
  NSString *t = [composeField_ stringValue]; if (![t length]) return;
  if (editMessageId_ != 0) {
    [bridge_ editMessageText:selectedChatId_ messageId:editMessageId_ text:t];
    [self cancelReplyEdit];
  } else {
    [bridge_ sendMessage:t chatId:selectedChatId_ replyTo:replyToMessageId_];
    if (replyToMessageId_ != 0) [self cancelReplyEdit];
  }
  [composeField_ setStringValue:@""];
}

- (void)cancelReplyEdit {
  replyToMessageId_ = 0; editMessageId_ = 0;
  if (replyBarContainer_) [replyBarContainer_ setHidden:YES];
  if (sendButton_) [sendButton_ setTitle:@"Send"];
  [self updateMainLayout];
}

- (NSMenu *)tableView:(NSTableView *)tv menuForEvent:(NSEvent *)event {
  if (tv != messageTable_) return nil;
  NSPoint pt = [tv convertPoint:[event locationInWindow] fromView:nil];
  NSInteger row = [tv rowAtPoint:pt];
  if (row < 0) return nil;
  [tv selectRow:row byExtendingSelection:NO];

  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  if (!ms || (NSUInteger)row >= [ms count]) return nil;
  NSDictionary *msg = [ms objectAtIndex:(NSUInteger)row];
  NSDictionary *sid = [msg objectForKey:@"sender_id"];
  long long suid = 0;
  if ([sid isKindOfClass:[NSDictionary class]]) suid = LongLongValue([sid objectForKey:@"user_id"]);
  BOOL isMine = (suid != 0 && meUserId_ != 0 && suid == meUserId_);

  NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Message"] autorelease];

  // Show more / collapse for long messages
  if ([ContentTypeForMessage(msg) isEqualToString:@"messageText"]) {
    long long mid = LongLongValue([msg objectForKey:@"id"]);
    NSString *txt = PreviewTextForMessage(msg);
    CGFloat maxW = MessageBubbleMaxWidthForColumnWidth([[[messageTable_ tableColumns] objectAtIndex:0] width], NO) - 16.0;
    if (maxW > 0 && TextHeightForWidth(txt, [NSFont systemFontOfSize:12], maxW, 0) > 80.0) {
      BOOL expanded = [expandedMessages_ containsObject:[NSNumber numberWithLongLong:mid]];
      NSMenuItem *expandItem = [menu addItemWithTitle:(expanded ? @"Show less" : @"Show more") action:@selector(toggleExpandAction:) keyEquivalent:@""];
       [expandItem setRepresentedObject:[NSNumber numberWithLongLong:mid]];
      [menu addItem:[NSMenuItem separatorItem]];
    }
  }

  // Play video if available
  NSString *pct = ContentTypeForMessage(msg);
  if ([pct isEqualToString:@"messageVideo"]) {
    NSString *vp = [self videoPathForMessage:msg requestDownload:NO];
    NSString *title = [vp length] ? @"Play Video" : @"Download & Play Video";
    NSMenuItem *playItem = [menu addItemWithTitle:title action:@selector(playVideoAction:) keyEquivalent:@""];
    [playItem setRepresentedObject:[vp length] ? (id)vp : (id)msg];
  }

  if (isMine) {
    NSMenuItem *editItem = [menu addItemWithTitle:@"Edit" action:@selector(messageEditAction:) keyEquivalent:@""];
    [editItem setRepresentedObject:[msg objectForKey:@"id"]];

    NSMenuItem *delItem = [menu addItemWithTitle:@"Delete" action:@selector(messageDeleteAction:) keyEquivalent:@""];
    [delItem setRepresentedObject:[msg objectForKey:@"id"]];
  }

  // Reactions submenu
  static const char *commonEmojiUtf8[] = {
    "\xF0\x9F\x91\x8D", "\xF0\x9F\x91\x8E", "\xE2\x9D\xA4\xEF\xB8\x8F",
    "\xF0\x9F\x94\xA5", "\xF0\x9F\xA5\xB0", "\xF0\x9F\x91\x8F",
    "\xF0\x9F\x98\x81", "\xF0\x9F\xA4\x94", "\xF0\x9F\x98\xA2",
    "\xF0\x9F\x98\xAE", "\xF0\x9F\xA4\xAC", "\xF0\x9F\x98\x8D",
    "\xF0\x9F\x98\x82", "\xF0\x9F\x98\xA1", "\xF0\x9F\x98\xB1",
    "\xF0\x9F\x90\xB3", "\xF0\x9F\x92\xAF", "\xF0\x9F\x91\x80",
    "\xF0\x9F\x8D\x8C"
  };
  NSMenu *rxMenu = [[[NSMenu alloc] initWithTitle:@"Reactions"] autorelease];
  NSUInteger commonEmojiCount = sizeof(commonEmojiUtf8) / sizeof(commonEmojiUtf8[0]);
  for (NSUInteger i = 0; i < commonEmojiCount; i++) {
    NSString *e = [NSString stringWithUTF8String:commonEmojiUtf8[i]];
    if (![e length]) continue;
    NSMenuItem *rxi = [rxMenu addItemWithTitle:e action:@selector(reactionAction:) keyEquivalent:@""];
    NSDictionary *rep = [NSDictionary dictionaryWithObjectsAndKeys:[msg objectForKey:@"id"], @"msgId", e, @"emoji", nil];
    [rxi setRepresentedObject:rep];
  }
  NSMenuItem *rxParent = [[[NSMenuItem alloc] initWithTitle:@"Reactions" action:NULL keyEquivalent:@""] autorelease];
  [rxParent setSubmenu:rxMenu];
  [menu insertItem:rxParent atIndex:0];
  return menu;
}

- (void)messageReplyAction:(NSMenuItem *)item {
  long long mid = LongLongValue([item representedObject]);
  if (!mid || !selectedChatId_) return;
  replyToMessageId_ = mid; editMessageId_ = 0;
  // Find the replied-to message and show preview
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  NSString *preview = @"";
  if (ms) {
    for (NSUInteger i = 0; i < [ms count]; i++) {
      NSDictionary *m = [ms objectAtIndex:i];
      if (LongLongValue([m objectForKey:@"id"]) == mid) {
        NSString *sn = [self userNameForSender:[m objectForKey:@"sender_id"]];
        NSString *pt = PreviewTextForMessage(m);
        if (![pt length]) pt = @"[Media]";
        preview = [NSString stringWithFormat:@"Replying to %@: %@", sn, pt];
        break;
      }
    }
  }
  [replyBarLabel_ setStringValue:preview];
  [replyBarContainer_ setHidden:NO];
  [self updateMainLayout];
  [sendButton_ setTitle:@"Reply"];
  [composeField_ selectText:nil];
  [mainWindow_ makeFirstResponder:composeField_];
}

- (void)messageEditAction:(NSMenuItem *)item {
  long long mid = LongLongValue([item representedObject]);
  if (!mid || !selectedChatId_) return;
  editMessageId_ = mid; replyToMessageId_ = 0;
  // Find the message text and put it in compose
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  if (ms) {
    for (NSUInteger i = 0; i < [ms count]; i++) {
      NSDictionary *m = [ms objectAtIndex:i];
      if (LongLongValue([m objectForKey:@"id"]) == mid) {
        [composeField_ setStringValue:PreviewTextForMessage(m)];
        break;
      }
    }
  }
  [replyBarLabel_ setStringValue:@"Editing message"];
  [replyBarContainer_ setHidden:NO];
  [self updateMainLayout];
  [sendButton_ setTitle:@"Save"];
  [composeField_ selectText:nil];
  [mainWindow_ makeFirstResponder:composeField_];
}

- (void)messageDeleteAction:(NSMenuItem *)item {
  long long mid = LongLongValue([item representedObject]);
  if (!mid || !selectedChatId_) return;
  [bridge_ deleteMessages:selectedChatId_ messageIds:[NSArray arrayWithObject:[NSNumber numberWithLongLong:mid]]];
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSMutableArray *ms = [messagesByChatId_ objectForKey:cid];
  if (ms) {
    for (NSUInteger i = 0; i < [ms count]; i++) {
      if (LongLongValue([[ms objectAtIndex:i] objectForKey:@"id"]) == mid) {
        [ms removeObjectAtIndex:i]; break;
      }
    }
  }
  [self refreshMessages]; [self refreshChats];
}

- (void)toggleExpandAction:(NSMenuItem *)item {
  NSNumber *mid = [item representedObject];
  if (!mid) return;
  if ([expandedMessages_ containsObject:mid]) {
    [expandedMessages_ removeObject:mid];
  } else {
    [expandedMessages_ addObject:mid];
  }
  [messageCellCache_ removeAllObjects];
  [self refreshMessages];
}

- (void)messageTableClicked:(id)sender {
  (void)sender;
  NSInteger row = [messageTable_ clickedRow];
  if (row < 0) return;
  NSNumber *cid = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cid];
  if (!ms || (NSUInteger)row >= [ms count]) return;
  NSDictionary *msg = [ms objectAtIndex:(NSUInteger)row];
  CGFloat mw = [[[messageTable_ tableColumns] objectAtIndex:0] width];
  NSDictionary *d = [self cachedMessageCellDictForMessage:msg maxWidth:mw];
  NSEvent *event = [NSApp currentEvent];
  NSPoint clickPoint = [messageTable_ convertPoint:[event locationInWindow] fromView:nil];
  NSRect rowRect = [messageTable_ rectOfRow:row];
  NSArray *links = [d objectForKey:@"linkItems"];
  if ([links isKindOfClass:[NSArray class]] && [links count] > 0) {
    NSRect textRect = NSZeroRect;
    NSString *displayText = nil;
    if (MessageBodyTextRectForDict(d, rowRect, mw, &textRect, &displayText)) {
      NSString *url = LinkURLAtPointInTextRect(displayText, links, textRect, clickPoint, [NSFont systemFontOfSize:12]);
      if ([url length]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NormalizedURLString(url)]];
        return;
      }
    }
  }
  NSString *webURL = StringOrEmpty([d objectForKey:@"webPageUrl"]);
  if ([webURL length] > 0) {
    NSRect previewRect = NSZeroRect;
    if (MessageWebPreviewRectForDict(d, rowRect, mw, &previewRect) && NSPointInRect(clickPoint, previewRect)) {
      [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NormalizedURLString(webURL)]];
      return;
    }
  }
  NSString *contentType = ContentTypeForMessage(msg);
  if ([contentType isEqualToString:@"messagePhoto"]) {
    NSRect mediaRect = NSZeroRect;
    if (MessageMediaRectForDict(d, rowRect, mw, &mediaRect) && NSPointInRect(clickPoint, mediaRect)) {
      NSString *path = StringOrEmpty([d objectForKey:@"imagePath"]);
      if ([path length] > 0) {
        [self showImagePreviewOverlayAtPath:path];
      } else {
        [self requestFileDownloadForMessage:msg];
        [self setStatusText:@"Image is downloading..."];
      }
      return;
    }
  }
  if ([contentType isEqualToString:@"messageVideo"]) {
    requestedVideoMessageId_ = LongLongValue([msg objectForKey:@"id"]);
    requestedVideoFileId_ = VideoFileId([msg objectForKey:@"content"]);
    NSString *path = [self videoPathForMessage:msg requestDownload:YES];
    if ([path length]) [self presentVideoAtPath:path row:row message:msg];
    return;
  }
  if (![contentType isEqualToString:@"messageText"]) return;
  long long mid = LongLongValue([msg objectForKey:@"id"]);
  NSString *txt = PreviewTextForMessage(msg);
  CGFloat maxW = MessageBubbleMaxWidthForColumnWidth(mw, NO) - 16.0;
  if (maxW <= 0 || TextHeightForWidth(txt, [NSFont systemFontOfSize:12], maxW, 0) <= 80.0) return;
  // Toggle
  NSNumber *midKey = [NSNumber numberWithLongLong:mid];
  if ([expandedMessages_ containsObject:midKey]) {
    [expandedMessages_ removeObject:midKey];
  } else {
    [expandedMessages_ addObject:midKey];
  }
  [messageCellCache_ removeAllObjects];
  [self refreshMessages];
}

- (void)openLinkAction:(NSMenuItem *)item {
  NSString *url = [item representedObject];
  if ([url isKindOfClass:[NSString class]] && [url length] > 0) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
  }
}

- (void)reactionAction:(NSMenuItem *)item {
  NSDictionary *rep = [item representedObject];
  if (![rep isKindOfClass:[NSDictionary class]]) return;
  long long mid = LongLongValue([rep objectForKey:@"msgId"]);
  NSString *emoji = [rep objectForKey:@"emoji"];
  if (!mid || ![emoji length] || !selectedChatId_) return;

  // Check if we already reacted with this emoji (toggle remove)
  NSNumber *cidKey = [NSNumber numberWithLongLong:selectedChatId_];
  NSArray *ms = [messagesByChatId_ objectForKey:cidKey];
  BOOL already = NO;
  if (ms) {
    for (NSUInteger i = 0; i < [ms count]; i++) {
      NSDictionary *m = [ms objectAtIndex:i];
      if (LongLongValue([m objectForKey:@"id"]) == mid) {
        NSDictionary *inter = [m objectForKey:@"interaction_info"];
        NSArray *rxs = [[inter objectForKey:@"reactions"] objectForKey:@"reactions"];
        for (NSUInteger j = 0; j < [rxs count]; j++) {
          NSDictionary *r = [rxs objectAtIndex:j];
          if ([StringOrEmpty([[r objectForKey:@"type"] objectForKey:@"emoji"]) isEqualToString:emoji] && [[r objectForKey:@"is_chosen"] boolValue]) {
            already = YES;
            break;
          }
        }
        break;
      }
    }
  }
  if (already) {
    [bridge_ removeReaction:selectedChatId_ messageId:mid emoji:emoji];
  } else {
    [bridge_ addReaction:selectedChatId_ messageId:mid emoji:emoji];
  }
}

- (IBAction)attachFile:(id)sender {
  (void)sender;
  if (!selectedChatId_) { [self setStatusText:@"Select a chat first."]; return; }
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  [panel setCanChooseFiles:YES];
  [panel setCanChooseDirectories:NO];
  [panel setAllowsMultipleSelection:NO];
  if ([panel runModalForDirectory:nil file:nil types:nil] == NSOKButton) {
    NSString *path = [[panel filename] stringByStandardizingPath];
    if ([path length] > 0) {
      [bridge_ sendFile:selectedChatId_ filePath:path caption:nil];
    }
  }
}

@end
