/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _UAPI_DVBVIDEO_H_
#define _UAPI_DVBVIDEO_H_
#include <linux/types.h>
#include <time.h>
typedef enum {
  VIDEO_FORMAT_4_3,
  VIDEO_FORMAT_16_9,
  VIDEO_FORMAT_221_1
} video_format_t;
typedef enum {
  VIDEO_PAN_SCAN,
  VIDEO_LETTER_BOX,
  VIDEO_CENTER_CUT_OUT
} video_displayformat_t;
typedef struct {
  int w;
  int h;
  video_format_t aspect_ratio;
} video_size_t;
typedef enum {
  VIDEO_SOURCE_DEMUX,
  VIDEO_SOURCE_MEMORY
} video_stream_source_t;
typedef enum {
  VIDEO_STOPPED,
  VIDEO_PLAYING,
  VIDEO_FREEZED
} video_play_state_t;
#define VIDEO_CMD_PLAY (0)
#define VIDEO_CMD_STOP (1)
#define VIDEO_CMD_FREEZE (2)
#define VIDEO_CMD_CONTINUE (3)
#define VIDEO_CMD_FREEZE_TO_BLACK (1 << 0)
#define VIDEO_CMD_STOP_TO_BLACK (1 << 0)
#define VIDEO_CMD_STOP_IMMEDIATELY (1 << 1)
#define VIDEO_PLAY_FMT_NONE (0)
#define VIDEO_PLAY_FMT_GOP (1)
struct video_command {
  __u32 cmd;
  __u32 flags;
  union {
    struct {
      __u64 pts;
    } stop;
    struct {
      __s32 speed;
      __u32 format;
    } play;
    struct {
      __u32 data[16];
    } raw;
  };
};
#define VIDEO_VSYNC_FIELD_UNKNOWN (0)
#define VIDEO_VSYNC_FIELD_ODD (1)
#define VIDEO_VSYNC_FIELD_EVEN (2)
#define VIDEO_VSYNC_FIELD_PROGRESSIVE (3)
struct video_event {
  __s32 type;
#define VIDEO_EVENT_SIZE_CHANGED 1
#define VIDEO_EVENT_FRAME_RATE_CHANGED 2
#define VIDEO_EVENT_DECODER_STOPPED 3
#define VIDEO_EVENT_VSYNC 4
  long timestamp;
  union {
    video_size_t size;
    unsigned int frame_rate;
    unsigned char vsync_field;
  } u;
};
struct video_status {
  int video_blank;
  video_play_state_t play_state;
  video_stream_source_t stream_source;
  video_format_t video_format;
  video_displayformat_t display_format;
};
struct video_still_picture {
  char __user * iFrame;
  __s32 size;
};
typedef __u16 video_attributes_t;
#define VIDEO_CAP_MPEG1 1
#define VIDEO_CAP_MPEG2 2
#define VIDEO_CAP_SYS 4
#define VIDEO_CAP_PROG 8
#define VIDEO_CAP_SPU 16
#define VIDEO_CAP_NAVI 32
#define VIDEO_CAP_CSS 64
#define VIDEO_STOP _IO('o', 21)
#define VIDEO_PLAY _IO('o', 22)
#define VIDEO_FREEZE _IO('o', 23)
#define VIDEO_CONTINUE _IO('o', 24)
#define VIDEO_SELECT_SOURCE _IO('o', 25)
#define VIDEO_SET_BLANK _IO('o', 26)
#define VIDEO_GET_STATUS _IOR('o', 27, struct video_status)
#define VIDEO_GET_EVENT _IOR('o', 28, struct video_event)
#define VIDEO_SET_DISPLAY_FORMAT _IO('o', 29)
#define VIDEO_STILLPICTURE _IOW('o', 30, struct video_still_picture)
#define VIDEO_FAST_FORWARD _IO('o', 31)
#define VIDEO_SLOWMOTION _IO('o', 32)
#define VIDEO_GET_CAPABILITIES _IOR('o', 33, unsigned int)
#define VIDEO_CLEAR_BUFFER _IO('o', 34)
#define VIDEO_SET_STREAMTYPE _IO('o', 36)
#define VIDEO_SET_FORMAT _IO('o', 37)
#define VIDEO_GET_SIZE _IOR('o', 55, video_size_t)
#define VIDEO_GET_PTS _IOR('o', 57, __u64)
#define VIDEO_GET_FRAME_COUNT _IOR('o', 58, __u64)
#define VIDEO_COMMAND _IOWR('o', 59, struct video_command)
#define VIDEO_TRY_COMMAND _IOWR('o', 60, struct video_command)
#endif