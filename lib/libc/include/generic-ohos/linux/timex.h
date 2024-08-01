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
#ifndef _UAPI_LINUX_TIMEX_H
#define _UAPI_LINUX_TIMEX_H
#include <linux/time.h>
#define NTP_API 4
struct timex {
  unsigned int modes;
  __kernel_long_t offset;
  __kernel_long_t freq;
  __kernel_long_t maxerror;
  __kernel_long_t esterror;
  int status;
  __kernel_long_t constant;
  __kernel_long_t precision;
  __kernel_long_t tolerance;
  struct timeval time;
  __kernel_long_t tick;
  __kernel_long_t ppsfreq;
  __kernel_long_t jitter;
  int shift;
  __kernel_long_t stabil;
  __kernel_long_t jitcnt;
  __kernel_long_t calcnt;
  __kernel_long_t errcnt;
  __kernel_long_t stbcnt;
  int tai;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
};
struct __kernel_timex_timeval {
  __kernel_time64_t tv_sec;
  long long tv_usec;
};
struct __kernel_timex {
  unsigned int modes;
  int : 32;
  long long offset;
  long long freq;
  long long maxerror;
  long long esterror;
  int status;
  int : 32;
  long long constant;
  long long precision;
  long long tolerance;
  struct __kernel_timex_timeval time;
  long long tick;
  long long ppsfreq;
  long long jitter;
  int shift;
  int : 32;
  long long stabil;
  long long jitcnt;
  long long calcnt;
  long long errcnt;
  long long stbcnt;
  int tai;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
  int : 32;
};
#define ADJ_OFFSET 0x0001
#define ADJ_FREQUENCY 0x0002
#define ADJ_MAXERROR 0x0004
#define ADJ_ESTERROR 0x0008
#define ADJ_STATUS 0x0010
#define ADJ_TIMECONST 0x0020
#define ADJ_TAI 0x0080
#define ADJ_SETOFFSET 0x0100
#define ADJ_MICRO 0x1000
#define ADJ_NANO 0x2000
#define ADJ_TICK 0x4000
#define ADJ_OFFSET_SINGLESHOT 0x8001
#define ADJ_OFFSET_SS_READ 0xa001
#define MOD_OFFSET ADJ_OFFSET
#define MOD_FREQUENCY ADJ_FREQUENCY
#define MOD_MAXERROR ADJ_MAXERROR
#define MOD_ESTERROR ADJ_ESTERROR
#define MOD_STATUS ADJ_STATUS
#define MOD_TIMECONST ADJ_TIMECONST
#define MOD_TAI ADJ_TAI
#define MOD_MICRO ADJ_MICRO
#define MOD_NANO ADJ_NANO
#define STA_PLL 0x0001
#define STA_PPSFREQ 0x0002
#define STA_PPSTIME 0x0004
#define STA_FLL 0x0008
#define STA_INS 0x0010
#define STA_DEL 0x0020
#define STA_UNSYNC 0x0040
#define STA_FREQHOLD 0x0080
#define STA_PPSSIGNAL 0x0100
#define STA_PPSJITTER 0x0200
#define STA_PPSWANDER 0x0400
#define STA_PPSERROR 0x0800
#define STA_CLOCKERR 0x1000
#define STA_NANO 0x2000
#define STA_MODE 0x4000
#define STA_CLK 0x8000
#define STA_RONLY (STA_PPSSIGNAL | STA_PPSJITTER | STA_PPSWANDER | STA_PPSERROR | STA_CLOCKERR | STA_NANO | STA_MODE | STA_CLK)
#define TIME_OK 0
#define TIME_INS 1
#define TIME_DEL 2
#define TIME_OOP 3
#define TIME_WAIT 4
#define TIME_ERROR 5
#define TIME_BAD TIME_ERROR
#endif