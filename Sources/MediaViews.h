#pragma once

#import "Common.h"

@interface MediaFrameView : NSView {
 @private
  NSString *thumbnailPath_;
  CGFloat controlsHeight_;
}
- (id)initWithFrame:(NSRect)frame thumbnailPath:(NSString *)thumbnailPath controlsHeight:(CGFloat)controlsHeight;
@end

@interface FrameBarView : NSView
@end

@interface PlaybackButtonView : NSControl {
 @private
  BOOL paused_;
  BOOL pressed_;
}
- (void)setPaused:(BOOL)paused;
- (BOOL)isPaused;
@end

@interface ImagePreviewOverlayView : NSView {
 @private
  NSImage *image_;
}
- (id)initWithFrame:(NSRect)frame image:(NSImage *)image;
@end

NSImage *ToolbarIconImage(NSString *name, CGFloat size);
void SetPlaybackButtonIcon(PlaybackButtonView *button, BOOL paused);
