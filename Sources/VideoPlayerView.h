#pragma once

#import "Common.h"

@interface VideoPlayerView : NSOpenGLView {
  AVFormatContext *fmtCtx_;
  AVCodecContext *codecCtx_;
  int videoStream_;
  struct SwsContext *swsCtx_;
  AVFrame *frame_;
  AVFrame *rgbFrame_;
  uint8_t *rgbBuf_;
  int rgbBufSize_;
  GLuint texture_;
  pthread_t decodeThread_;
  pthread_mutex_t mutex_;
  volatile int paused_;
  volatile int stopped_;
  volatile int frameReady_;
  volatile int decodedFrames_;
  volatile int decodeThreadStarted_;
  volatile int mutexReady_;
  volatile int seekRequested_;
  double seekTargetSeconds_;
  double currentTimeSeconds_;
  double durationSeconds_;
}
- (id)initWithFrame:(NSRect)frame path:(NSString *)path;
- (void)stop;
- (void)setPaused:(BOOL)paused;
- (BOOL)isPaused;
- (void)seekToSeconds:(double)seconds;
- (double)currentTimeSeconds;
- (double)durationSeconds;
- (BOOL)hasDecodedFrame;
- (BOOL)hasPendingFrame;
@end
