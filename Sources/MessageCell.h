#pragma once

#import "Common.h"

@interface MessageCell : NSCell {
  NSString *senderName_;
  NSString *messageText_;
  BOOL isOutgoing_;
  NSString *timestampStr_;
  NSString *contentType_;
  NSString *imagePath_;
  long long imageWidth_;
  long long imageHeight_;
  int fileDownloadPriority_;
  NSNumber *fileIdToDownload_;
  BOOL hideMediaThumbnail_;
  CGFloat maxWidth_;
  NSString *senderAvatarPath_;
  NSString *senderInitial_;
  NSString *replyPreview_;
  BOOL isLongMessage_;
  BOOL isExpanded_;
  long long messageId_;
  NSString *webPageUrl_;
  NSString *webPageTitle_;
  NSString *webPageDescription_;
  NSString *webPageSite_;
  NSString *webPagePhotoPath_;
  long long webPagePhotoWidth_;
  long long webPagePhotoHeight_;
  BOOL webPageHasPhoto_;
  NSArray *linkItems_;
  NSArray *reactions_;
}
- (void)configureWithMessageDict:(NSDictionary *)dict;
+ (CGFloat)cellHeightForMessageDict:(NSDictionary *)dict maxWidth:(CGFloat)maxWidth;
@end

BOOL MessageBodyTextRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut, NSString **displayTextOut);
BOOL MessageMediaRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut);
BOOL MessageWebPreviewRectForDict(NSDictionary *dict, NSRect cellFrame, CGFloat maxWidth, NSRect *rectOut);
