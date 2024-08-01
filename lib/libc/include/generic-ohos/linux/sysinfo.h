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
#ifndef _LINUX_SYSINFO_H
#define _LINUX_SYSINFO_H
#include <linux/types.h>
#define SI_LOAD_SHIFT 16
struct sysinfo {
  __kernel_long_t uptime;
  __kernel_ulong_t loads[3];
  __kernel_ulong_t totalram;
  __kernel_ulong_t freeram;
  __kernel_ulong_t sharedram;
  __kernel_ulong_t bufferram;
  __kernel_ulong_t totalswap;
  __kernel_ulong_t freeswap;
  __u16 procs;
  __u16 pad;
  __kernel_ulong_t totalhigh;
  __kernel_ulong_t freehigh;
  __u32 mem_unit;
  char _f[20 - 2 * sizeof(__kernel_ulong_t) - sizeof(__u32)];
};
#endif