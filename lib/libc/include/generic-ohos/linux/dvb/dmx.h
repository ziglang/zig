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
#ifndef _UAPI_DVBDMX_H_
#define _UAPI_DVBDMX_H_
#include <linux/types.h>
#include <time.h>
#define DMX_FILTER_SIZE 16
enum dmx_output {
  DMX_OUT_DECODER,
  DMX_OUT_TAP,
  DMX_OUT_TS_TAP,
  DMX_OUT_TSDEMUX_TAP
};
enum dmx_input {
  DMX_IN_FRONTEND,
  DMX_IN_DVR
};
enum dmx_ts_pes {
  DMX_PES_AUDIO0,
  DMX_PES_VIDEO0,
  DMX_PES_TELETEXT0,
  DMX_PES_SUBTITLE0,
  DMX_PES_PCR0,
  DMX_PES_AUDIO1,
  DMX_PES_VIDEO1,
  DMX_PES_TELETEXT1,
  DMX_PES_SUBTITLE1,
  DMX_PES_PCR1,
  DMX_PES_AUDIO2,
  DMX_PES_VIDEO2,
  DMX_PES_TELETEXT2,
  DMX_PES_SUBTITLE2,
  DMX_PES_PCR2,
  DMX_PES_AUDIO3,
  DMX_PES_VIDEO3,
  DMX_PES_TELETEXT3,
  DMX_PES_SUBTITLE3,
  DMX_PES_PCR3,
  DMX_PES_OTHER
};
#define DMX_PES_AUDIO DMX_PES_AUDIO0
#define DMX_PES_VIDEO DMX_PES_VIDEO0
#define DMX_PES_TELETEXT DMX_PES_TELETEXT0
#define DMX_PES_SUBTITLE DMX_PES_SUBTITLE0
#define DMX_PES_PCR DMX_PES_PCR0
struct dmx_filter {
  __u8 filter[DMX_FILTER_SIZE];
  __u8 mask[DMX_FILTER_SIZE];
  __u8 mode[DMX_FILTER_SIZE];
};
struct dmx_sct_filter_params {
  __u16 pid;
  struct dmx_filter filter;
  __u32 timeout;
  __u32 flags;
#define DMX_CHECK_CRC 1
#define DMX_ONESHOT 2
#define DMX_IMMEDIATE_START 4
};
struct dmx_pes_filter_params {
  __u16 pid;
  enum dmx_input input;
  enum dmx_output output;
  enum dmx_ts_pes pes_type;
  __u32 flags;
};
struct dmx_stc {
  unsigned int num;
  unsigned int base;
  __u64 stc;
};
enum dmx_buffer_flags {
  DMX_BUFFER_FLAG_HAD_CRC32_DISCARD = 1 << 0,
  DMX_BUFFER_FLAG_TEI = 1 << 1,
  DMX_BUFFER_PKT_COUNTER_MISMATCH = 1 << 2,
  DMX_BUFFER_FLAG_DISCONTINUITY_DETECTED = 1 << 3,
  DMX_BUFFER_FLAG_DISCONTINUITY_INDICATOR = 1 << 4,
};
struct dmx_buffer {
  __u32 index;
  __u32 bytesused;
  __u32 offset;
  __u32 length;
  __u32 flags;
  __u32 count;
};
struct dmx_requestbuffers {
  __u32 count;
  __u32 size;
};
struct dmx_exportbuffer {
  __u32 index;
  __u32 flags;
  __s32 fd;
};
#define DMX_START _IO('o', 41)
#define DMX_STOP _IO('o', 42)
#define DMX_SET_FILTER _IOW('o', 43, struct dmx_sct_filter_params)
#define DMX_SET_PES_FILTER _IOW('o', 44, struct dmx_pes_filter_params)
#define DMX_SET_BUFFER_SIZE _IO('o', 45)
#define DMX_GET_PES_PIDS _IOR('o', 47, __u16[5])
#define DMX_GET_STC _IOWR('o', 50, struct dmx_stc)
#define DMX_ADD_PID _IOW('o', 51, __u16)
#define DMX_REMOVE_PID _IOW('o', 52, __u16)
typedef enum dmx_output dmx_output_t;
typedef enum dmx_input dmx_input_t;
typedef enum dmx_ts_pes dmx_pes_type_t;
typedef struct dmx_filter dmx_filter_t;
#define DMX_REQBUFS _IOWR('o', 60, struct dmx_requestbuffers)
#define DMX_QUERYBUF _IOWR('o', 61, struct dmx_buffer)
#define DMX_EXPBUF _IOWR('o', 62, struct dmx_exportbuffer)
#define DMX_QBUF _IOWR('o', 63, struct dmx_buffer)
#define DMX_DQBUF _IOWR('o', 64, struct dmx_buffer)
#endif