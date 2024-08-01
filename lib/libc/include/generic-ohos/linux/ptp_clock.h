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
#ifndef _PTP_CLOCK_H_
#define _PTP_CLOCK_H_
#include <linux/ioctl.h>
#include <linux/types.h>
#define PTP_ENABLE_FEATURE (1 << 0)
#define PTP_RISING_EDGE (1 << 1)
#define PTP_FALLING_EDGE (1 << 2)
#define PTP_STRICT_FLAGS (1 << 3)
#define PTP_EXTTS_EDGES (PTP_RISING_EDGE | PTP_FALLING_EDGE)
#define PTP_EXTTS_VALID_FLAGS (PTP_ENABLE_FEATURE | PTP_RISING_EDGE | PTP_FALLING_EDGE | PTP_STRICT_FLAGS)
#define PTP_EXTTS_V1_VALID_FLAGS (PTP_ENABLE_FEATURE | PTP_RISING_EDGE | PTP_FALLING_EDGE)
#define PTP_PEROUT_ONE_SHOT (1 << 0)
#define PTP_PEROUT_DUTY_CYCLE (1 << 1)
#define PTP_PEROUT_PHASE (1 << 2)
#define PTP_PEROUT_VALID_FLAGS (PTP_PEROUT_ONE_SHOT | PTP_PEROUT_DUTY_CYCLE | PTP_PEROUT_PHASE)
#define PTP_PEROUT_V1_VALID_FLAGS (0)
struct ptp_clock_time {
  __s64 sec;
  __u32 nsec;
  __u32 reserved;
};
struct ptp_clock_caps {
  int max_adj;
  int n_alarm;
  int n_ext_ts;
  int n_per_out;
  int pps;
  int n_pins;
  int cross_timestamping;
  int adjust_phase;
  int rsv[12];
};
struct ptp_extts_request {
  unsigned int index;
  unsigned int flags;
  unsigned int rsv[2];
};
struct ptp_perout_request {
  union {
    struct ptp_clock_time start;
    struct ptp_clock_time phase;
  };
  struct ptp_clock_time period;
  unsigned int index;
  unsigned int flags;
  union {
    struct ptp_clock_time on;
    unsigned int rsv[4];
  };
};
#define PTP_MAX_SAMPLES 25
struct ptp_sys_offset {
  unsigned int n_samples;
  unsigned int rsv[3];
  struct ptp_clock_time ts[2 * PTP_MAX_SAMPLES + 1];
};
struct ptp_sys_offset_extended {
  unsigned int n_samples;
  unsigned int rsv[3];
  struct ptp_clock_time ts[PTP_MAX_SAMPLES][3];
};
struct ptp_sys_offset_precise {
  struct ptp_clock_time device;
  struct ptp_clock_time sys_realtime;
  struct ptp_clock_time sys_monoraw;
  unsigned int rsv[4];
};
enum ptp_pin_function {
  PTP_PF_NONE,
  PTP_PF_EXTTS,
  PTP_PF_PEROUT,
  PTP_PF_PHYSYNC,
};
struct ptp_pin_desc {
  char name[64];
  unsigned int index;
  unsigned int func;
  unsigned int chan;
  unsigned int rsv[5];
};
#define PTP_CLK_MAGIC '='
#define PTP_CLOCK_GETCAPS _IOR(PTP_CLK_MAGIC, 1, struct ptp_clock_caps)
#define PTP_EXTTS_REQUEST _IOW(PTP_CLK_MAGIC, 2, struct ptp_extts_request)
#define PTP_PEROUT_REQUEST _IOW(PTP_CLK_MAGIC, 3, struct ptp_perout_request)
#define PTP_ENABLE_PPS _IOW(PTP_CLK_MAGIC, 4, int)
#define PTP_SYS_OFFSET _IOW(PTP_CLK_MAGIC, 5, struct ptp_sys_offset)
#define PTP_PIN_GETFUNC _IOWR(PTP_CLK_MAGIC, 6, struct ptp_pin_desc)
#define PTP_PIN_SETFUNC _IOW(PTP_CLK_MAGIC, 7, struct ptp_pin_desc)
#define PTP_SYS_OFFSET_PRECISE _IOWR(PTP_CLK_MAGIC, 8, struct ptp_sys_offset_precise)
#define PTP_SYS_OFFSET_EXTENDED _IOWR(PTP_CLK_MAGIC, 9, struct ptp_sys_offset_extended)
#define PTP_CLOCK_GETCAPS2 _IOR(PTP_CLK_MAGIC, 10, struct ptp_clock_caps)
#define PTP_EXTTS_REQUEST2 _IOW(PTP_CLK_MAGIC, 11, struct ptp_extts_request)
#define PTP_PEROUT_REQUEST2 _IOW(PTP_CLK_MAGIC, 12, struct ptp_perout_request)
#define PTP_ENABLE_PPS2 _IOW(PTP_CLK_MAGIC, 13, int)
#define PTP_SYS_OFFSET2 _IOW(PTP_CLK_MAGIC, 14, struct ptp_sys_offset)
#define PTP_PIN_GETFUNC2 _IOWR(PTP_CLK_MAGIC, 15, struct ptp_pin_desc)
#define PTP_PIN_SETFUNC2 _IOW(PTP_CLK_MAGIC, 16, struct ptp_pin_desc)
#define PTP_SYS_OFFSET_PRECISE2 _IOWR(PTP_CLK_MAGIC, 17, struct ptp_sys_offset_precise)
#define PTP_SYS_OFFSET_EXTENDED2 _IOWR(PTP_CLK_MAGIC, 18, struct ptp_sys_offset_extended)
struct ptp_extts_event {
  struct ptp_clock_time t;
  unsigned int index;
  unsigned int flags;
  unsigned int rsv[2];
};
#endif