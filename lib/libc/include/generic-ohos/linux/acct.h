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
#ifndef _UAPI_LINUX_ACCT_H
#define _UAPI_LINUX_ACCT_H
#include <linux/types.h>
#include <asm/param.h>
#include <asm/byteorder.h>
typedef __u16 comp_t;
typedef __u32 comp2_t;
#define ACCT_COMM 16
struct acct {
  char ac_flag;
  char ac_version;
  __u16 ac_uid16;
  __u16 ac_gid16;
  __u16 ac_tty;
  __u32 ac_btime;
  comp_t ac_utime;
  comp_t ac_stime;
  comp_t ac_etime;
  comp_t ac_mem;
  comp_t ac_io;
  comp_t ac_rw;
  comp_t ac_minflt;
  comp_t ac_majflt;
  comp_t ac_swaps;
  __u16 ac_ahz;
  __u32 ac_exitcode;
  char ac_comm[ACCT_COMM + 1];
  __u8 ac_etime_hi;
  __u16 ac_etime_lo;
  __u32 ac_uid;
  __u32 ac_gid;
};
struct acct_v3 {
  char ac_flag;
  char ac_version;
  __u16 ac_tty;
  __u32 ac_exitcode;
  __u32 ac_uid;
  __u32 ac_gid;
  __u32 ac_pid;
  __u32 ac_ppid;
  __u32 ac_btime;
  float ac_etime;
  comp_t ac_utime;
  comp_t ac_stime;
  comp_t ac_mem;
  comp_t ac_io;
  comp_t ac_rw;
  comp_t ac_minflt;
  comp_t ac_majflt;
  comp_t ac_swaps;
  char ac_comm[ACCT_COMM];
};
#define AFORK 0x01
#define ASU 0x02
#define ACOMPAT 0x04
#define ACORE 0x08
#define AXSIG 0x10
#if defined(__BYTE_ORDER) ? __BYTE_ORDER == __BIG_ENDIAN : defined(__BIG_ENDIAN)
#define ACCT_BYTEORDER 0x80
#elif defined(__BYTE_ORDER)?__BYTE_ORDER==__LITTLE_ENDIAN:defined(__LITTLE_ENDIAN)
#define ACCT_BYTEORDER 0x00
#else
#error unspecified endianness
#endif
#define ACCT_VERSION 2
#define AHZ (HZ)
#endif