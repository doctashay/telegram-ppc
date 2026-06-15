#pragma once

#import "Common.h"

NSArray *EmojiSegmentsFromText(NSString *text);
NSImage *TwemojiImageForKey(NSString *emojiKey);
NSImage *TwemojiImageForSegment(NSDictionary *seg);
void DrawMissingEmojiGlyph(NSRect rect, NSColor *color);
void DrawEmojiText(NSArray *segments, NSRect bounds, NSColor *color, NSFont *font);
void DrawSingleLineEmojiText(NSString *text, NSRect bounds, NSColor *color, NSFont *font);
NSString *TruncatedStringForWidth(NSString *text, NSDictionary *attrs, CGFloat maxWidth);
