#pragma once

#import "Common.h"

NSArray *LinkItemsFromTextAndEntities(NSString *text, NSArray *entities);
NSArray *LinkItemsForMessageContent(NSDictionary *content);
void DrawTextWithLinks(NSString *text, NSArray *links, NSRect rect, NSColor *textColor, NSColor *linkColor, NSFont *font);
NSString *LinkURLAtPointInTextRect(NSString *text, NSArray *links, NSRect rect, NSPoint point, NSFont *font);
NSString *MessagePreviewFromContent(NSDictionary *content);
NSString *PreviewTextForMessage(NSDictionary *message);
NSString *ContentTypeForMessage(NSDictionary *message);
NSNumber *PhotoFileIdFromContent(NSDictionary *content);
NSString *PhotoLocalPathFromContent(NSDictionary *content);
long long PhotoWidthForContent(NSDictionary *content);
long long PhotoHeightForContent(NSDictionary *content);
long long PhotoSmallFileIdFromPhotoDict(NSDictionary *photo);
NSString *ProfilePhotoLocalPath(NSDictionary *profilePhoto);
NSDictionary *LargestPhotoSizeFromPhotoDict(NSDictionary *photo);
NSDictionary *LargestPhotoFileFromPhotoDict(NSDictionary *photo);
long long ThumbnailFileIdFromDict(NSDictionary *thumb);
NSString *ThumbnailLocalPathFromDict(NSDictionary *thumb);
BOOL PreviewImageFromDictRecursive(NSDictionary *dict, int depth, long long *fidOut, NSString **pathOut, long long *widthOut, long long *heightOut);
long long PreviewImageFileIdFromWebPageDict(NSDictionary *webPage, NSString **localPathOut, long long *widthOut, long long *heightOut);
long long VideoThumbnailFileId(NSDictionary *content);
long long VideoFileId(NSDictionary *content);
NSString *VideoThumbnailLocalPath(NSDictionary *content);
NSComparisonResult CompareOrderStrings(NSString *lhs, NSString *rhs);
NSInteger CompareChatIds(id lhs, id rhs, void *context);
NSInteger CompareMessagesById(id lhs, id rhs, void *context);
CGFloat TextHeightForWidth(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines);
CGFloat TextHeightForWidthAndBreakMode(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines, NSLineBreakMode mode);
CGFloat TextHeightForWidthUncapped(NSString *text, NSFont *font, CGFloat width);
CGFloat MessageBubbleMaxWidthForColumnWidth(CGFloat columnWidth, BOOL isOutgoing);
NSUInteger EstimatedLineCountForText(NSString *text, NSFont *font, CGFloat maxWidth);
CGFloat FastTextHeightEstimate(NSString *text, NSFont *font, CGFloat width);
NSString *TruncatedText(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines);
NSString *NormalizePreviewDescription(NSString *desc);
CGFloat WebPreviewTextHeight(NSString *text, NSFont *font, CGFloat maxWidth, int maxLines);
CGFloat ReactionBadgesHeight(NSArray *reactions, CGFloat maxWidth);
CGFloat EstimatedReactionBadgesHeightForCount(NSUInteger count, CGFloat maxWidth);
NSSize WebPreviewImageSize(CGFloat maxWidth, long long imageWidth, long long imageHeight);
CGFloat MaxMediaPreviewHeightForContentType(NSString *contentType);
NSSize MediaPreviewSize(CGFloat maxWidth, long long imageWidth, long long imageHeight, NSString *contentType);
CGFloat WebPreviewCardHeight(CGFloat cardWidth, BOOL hasPhoto, long long imageWidth, long long imageHeight, NSString *site, NSString *title, NSString *desc);
CGFloat EstimatedCellHeightForDict(NSDictionary *message, CGFloat maxWidth);
CGFloat EstimatedReactionBadgeWidth(NSDictionary *reaction);
