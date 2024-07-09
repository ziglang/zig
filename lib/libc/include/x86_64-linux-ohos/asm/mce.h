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
#ifndef _UAPI_ASM_X86_MCE_H
#define _UAPI_ASM_X86_MCE_H
#include <linux/types.h>
#include <linux/ioctl.h>
struct mce {
  __u64 status;
  __u64 misc;
  __u64 addr;
  __u64 mcgstatus;
  __u64 ip;
  __u64 tsc;
  __u64 time;
  __u8 cpuvendor;
  __u8 inject_flags;
  __u8 severity;
  __u8 pad;
  __u32 cpuid;
  __u8 cs;
  __u8 bank;
  __u8 cpu;
  __u8 finished;
  __u32 extcpu;
  __u32 socketid;
  __u32 apicid;
  __u64 mcgcap;
  __u64 synd;
  __u64 ipid;
  __u64 ppin;
  __u32 microcode;
  __u64 kflags;
};
#define MCE_GET_RECORD_LEN _IOR('M', 1, int)
#define MCE_GET_LOG_LEN _IOR('M', 2, int)
#define MCE_GETCLEAR_FLAGS _IOR('M', 3, int)
#endif
