#import "VideoPlayerView.h"

@implementation VideoPlayerView

static void *DecodeThread(void *arg) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  VideoPlayerView *v = (VideoPlayerView *)arg;
  AVPacket *pkt = av_packet_alloc();
  if (!pkt) {
    [pool release];
    return NULL;
  }
  int packets = 0;
  while (!v->stopped_) {
    pthread_mutex_lock(&v->mutex_);
    int paused = v->paused_;
    int seek = v->seekRequested_;
    double seekTarget = v->seekTargetSeconds_;
    if (seek) v->seekRequested_ = 0;
    pthread_mutex_unlock(&v->mutex_);

    if (seek) {
      AVRational tb = v->fmtCtx_->streams[v->videoStream_]->time_base;
      int64_t ts = (int64_t)(seekTarget / av_q2d(tb));
      av_seek_frame(v->fmtCtx_, v->videoStream_, ts, AVSEEK_FLAG_BACKWARD);
      avcodec_flush_buffers(v->codecCtx_);
      pthread_mutex_lock(&v->mutex_);
      v->currentTimeSeconds_ = seekTarget;
      v->frameReady_ = 0;
      pthread_mutex_unlock(&v->mutex_);
    }

    if (paused) {
      struct timespec pts = {0, 20000000};
      nanosleep(&pts, NULL);
      continue;
    }

    int ret = av_read_frame(v->fmtCtx_, pkt);
    if (ret < 0) {
      pthread_mutex_lock(&v->mutex_);
      v->paused_ = 1;
      pthread_mutex_unlock(&v->mutex_);
      struct timespec ets = {0, 50000000};
      nanosleep(&ets, NULL);
      break;
    }
    if (pkt->stream_index == v->videoStream_) {
      packets++;
      ret = avcodec_send_packet(v->codecCtx_, pkt);
      if (ret < 0) {
        av_packet_unref(pkt);
        continue;
      }
      while (!v->stopped_ && (ret = avcodec_receive_frame(v->codecCtx_, v->frame_)) == 0) {
        pthread_mutex_lock(&v->mutex_);
        sws_scale(v->swsCtx_, v->frame_->data, v->frame_->linesize, 0, v->codecCtx_->height, v->rgbFrame_->data, v->rgbFrame_->linesize);
        int64_t bestTs = v->frame_->best_effort_timestamp;
        if (bestTs != AV_NOPTS_VALUE) {
          v->currentTimeSeconds_ = (double)bestTs * av_q2d(v->fmtCtx_->streams[v->videoStream_]->time_base);
        }
        v->frameReady_ = 1;
        v->decodedFrames_ = v->decodedFrames_ + 1;
        pthread_mutex_unlock(&v->mutex_);
        // Limit to ~30fps
        struct timespec ts = {0, 33000000};
        nanosleep(&ts, NULL);
      }
    }
    av_packet_unref(pkt);
  }
  av_packet_free(&pkt);
  [pool release];
  return NULL;
}

- (id)initWithFrame:(NSRect)frame path:(NSString *)path {
  NSOpenGLPixelFormatAttribute attrs[] = {
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute)24,
    NSOpenGLPFAAlphaSize, (NSOpenGLPixelFormatAttribute)8,
    (NSOpenGLPixelFormatAttribute)0
  };
  NSOpenGLPixelFormat *pf = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attrs] autorelease];
  self = [super initWithFrame:frame pixelFormat:pf];
  if (!self) return nil;

  const char *fp = [path fileSystemRepresentation];
  fmtCtx_ = NULL;
  if (avformat_open_input(&fmtCtx_, fp, NULL, NULL) < 0) { [self release]; return nil; }
  avformat_find_stream_info(fmtCtx_, NULL);
  videoStream_ = -1;
  for (unsigned int i = 0; i < fmtCtx_->nb_streams; i++) {
    if (fmtCtx_->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) { videoStream_ = i; break; }
  }
  if (videoStream_ < 0) { avformat_close_input(&fmtCtx_); [self release]; return nil; }

  const AVCodec *codec = avcodec_find_decoder(fmtCtx_->streams[videoStream_]->codecpar->codec_id);
  if (!codec) { avformat_close_input(&fmtCtx_); [self release]; return nil; }
  codecCtx_ = avcodec_alloc_context3(codec);
  if (!codecCtx_) { avformat_close_input(&fmtCtx_); [self release]; return nil; }
  avcodec_parameters_to_context(codecCtx_, fmtCtx_->streams[videoStream_]->codecpar);
  if (avcodec_open2(codecCtx_, codec, NULL) < 0) {
    avcodec_free_context(&codecCtx_);
    avformat_close_input(&fmtCtx_);
    [self release];
    return nil;
  }

  frame_ = av_frame_alloc();
  rgbFrame_ = av_frame_alloc();
  rgbBufSize_ = av_image_get_buffer_size(AV_PIX_FMT_RGB24, codecCtx_->width, codecCtx_->height, 1);
  rgbBuf_ = (uint8_t *)av_malloc(rgbBufSize_);
  if (!frame_ || !rgbFrame_ || !rgbBuf_) { [self release]; return nil; }
  av_image_fill_arrays(rgbFrame_->data, rgbFrame_->linesize, rgbBuf_, AV_PIX_FMT_RGB24, codecCtx_->width, codecCtx_->height, 1);
  swsCtx_ = sws_getContext(codecCtx_->width, codecCtx_->height, codecCtx_->pix_fmt, codecCtx_->width, codecCtx_->height, AV_PIX_FMT_RGB24, SWS_BILINEAR, NULL, NULL, NULL);
  if (!swsCtx_) { [self release]; return nil; }

  pthread_mutex_init(&mutex_, NULL);
  mutexReady_ = 1;
  frameReady_ = 0; stopped_ = 0; paused_ = 0;
  seekRequested_ = 0; seekTargetSeconds_ = 0.0; currentTimeSeconds_ = 0.0;
  durationSeconds_ = 0.0;
  if (fmtCtx_->duration > 0) durationSeconds_ = (double)fmtCtx_->duration / (double)AV_TIME_BASE;
  decodedFrames_ = 0;
  texture_ = 0;
  if (pthread_create(&decodeThread_, NULL, DecodeThread, self) == 0) decodeThreadStarted_ = 1;
  else { [self release]; return nil; }

  return self;
}

- (void)drawRect:(NSRect)r {
  (void)r;
  [[self openGLContext] makeCurrentContext];
  NSRect bounds = [self bounds];
  glViewport(0, 0, (GLsizei)bounds.size.width, (GLsizei)bounds.size.height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  glOrtho(0, bounds.size.width, 0, bounds.size.height, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  glClearColor(0, 0, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);

  if (stopped_ || !mutexReady_ || !codecCtx_) {
    [[self openGLContext] flushBuffer];
    return;
  }

  pthread_mutex_lock(&mutex_);
  if (frameReady_ && rgbBuf_) {
    if (!texture_) {
      glGenTextures(1, &texture_);
      glBindTexture(GL_TEXTURE_2D, texture_);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, codecCtx_->width, codecCtx_->height, 0, GL_RGB, GL_UNSIGNED_BYTE, rgbBuf_);
    } else {
      glBindTexture(GL_TEXTURE_2D, texture_);
      glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, codecCtx_->width, codecCtx_->height, GL_RGB, GL_UNSIGNED_BYTE, rgbBuf_);
    }
    frameReady_ = 0;
  }
  BOOL canDraw = (texture_ != 0 && codecCtx_ != NULL);
  pthread_mutex_unlock(&mutex_);

  if (canDraw) {
    GLfloat w = codecCtx_->width, h = codecCtx_->height;
    GLfloat vw = bounds.size.width, vh = bounds.size.height;
    GLfloat scale = (vw / w < vh / h) ? (vw / w) : (vh / h);
    GLfloat dw = w * scale, dh = h * scale;
    GLfloat ox = (vw - dw) / 2.0f, oy = (vh - dh) / 2.0f;

    glEnable(GL_TEXTURE_2D);
    glBegin(GL_QUADS);
    glTexCoord2f(0, 1); glVertex2f(ox, oy);
    glTexCoord2f(1, 1); glVertex2f(ox + dw, oy);
    glTexCoord2f(1, 0); glVertex2f(ox + dw, oy + dh);
    glTexCoord2f(0, 0); glVertex2f(ox, oy + dh);
    glEnd();
    glDisable(GL_TEXTURE_2D);
  }
  [[self openGLContext] flushBuffer];
}

- (void)mouseDown:(NSEvent *)e {
  (void)e;
  [self setPaused:![self isPaused]];
}

- (void)setPaused:(BOOL)paused {
  if (!mutexReady_) return;
  pthread_mutex_lock(&mutex_);
  paused_ = paused ? 1 : 0;
  pthread_mutex_unlock(&mutex_);
}

- (BOOL)isPaused {
  if (!mutexReady_) return YES;
  pthread_mutex_lock(&mutex_);
  BOOL p = paused_ ? YES : NO;
  pthread_mutex_unlock(&mutex_);
  return p;
}

- (void)seekToSeconds:(double)seconds {
  if (!mutexReady_ || durationSeconds_ <= 0.0) return;
  if (seconds < 0.0) seconds = 0.0;
  if (seconds > durationSeconds_) seconds = durationSeconds_;
  pthread_mutex_lock(&mutex_);
  seekTargetSeconds_ = seconds;
  seekRequested_ = 1;
  paused_ = 0;
  pthread_mutex_unlock(&mutex_);
}

- (double)currentTimeSeconds {
  if (!mutexReady_) return 0.0;
  pthread_mutex_lock(&mutex_);
  double t = currentTimeSeconds_;
  pthread_mutex_unlock(&mutex_);
  return t;
}

- (double)durationSeconds {
  return durationSeconds_;
}

- (BOOL)hasDecodedFrame {
  if (!mutexReady_) return NO;
  pthread_mutex_lock(&mutex_);
  BOOL hasFrame = decodedFrames_ > 0;
  pthread_mutex_unlock(&mutex_);
  return hasFrame;
}

- (BOOL)hasPendingFrame {
  if (!mutexReady_) return NO;
  pthread_mutex_lock(&mutex_);
  BOOL pending = frameReady_ ? YES : NO;
  pthread_mutex_unlock(&mutex_);
  return pending;
}

- (void)stop {
  if (stopped_) return;
  stopped_ = 1;
  if (decodeThreadStarted_) { pthread_join(decodeThread_, NULL); decodeThreadStarted_ = 0; }
  if (texture_) { [[self openGLContext] makeCurrentContext]; glDeleteTextures(1, &texture_); texture_ = 0; }
  if (frame_) av_frame_free(&frame_);
  if (rgbFrame_) av_frame_free(&rgbFrame_);
  if (rgbBuf_) { av_free(rgbBuf_); rgbBuf_ = NULL; }
  if (swsCtx_) { sws_freeContext(swsCtx_); swsCtx_ = NULL; }
  if (codecCtx_) avcodec_free_context(&codecCtx_);
  if (fmtCtx_) avformat_close_input(&fmtCtx_);
  if (mutexReady_) { pthread_mutex_destroy(&mutex_); mutexReady_ = 0; }
}

- (void)dealloc {
  [self stop];
  [super dealloc];
}

@end
