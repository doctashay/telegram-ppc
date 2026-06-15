#pragma once

#import "Common.h"

NSImage *CachedImageAtPath(NSString *path);
NSImage *ScaledCachedImageAtPath(NSString *path, CGFloat width, CGFloat height, BOOL flipped);
void StrokeRoundedBorder(NSRect rect, CGFloat radius, NSColor *color);
NSSize ImagePixelSize(NSImage *img);
void DrawImageInRectUpright(NSImage *img, NSRect rect);
void DrawRoundedImage(NSImage *img, NSRect rect, CGFloat radius, NSColor *borderColor);
