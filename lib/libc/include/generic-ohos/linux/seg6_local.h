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
#ifndef _UAPI_LINUX_SEG6_LOCAL_H
#define _UAPI_LINUX_SEG6_LOCAL_H
#include <linux/seg6.h>
enum {
  SEG6_LOCAL_UNSPEC,
  SEG6_LOCAL_ACTION,
  SEG6_LOCAL_SRH,
  SEG6_LOCAL_TABLE,
  SEG6_LOCAL_NH4,
  SEG6_LOCAL_NH6,
  SEG6_LOCAL_IIF,
  SEG6_LOCAL_OIF,
  SEG6_LOCAL_BPF,
  __SEG6_LOCAL_MAX,
};
#define SEG6_LOCAL_MAX (__SEG6_LOCAL_MAX - 1)
enum {
  SEG6_LOCAL_ACTION_UNSPEC = 0,
  SEG6_LOCAL_ACTION_END = 1,
  SEG6_LOCAL_ACTION_END_X = 2,
  SEG6_LOCAL_ACTION_END_T = 3,
  SEG6_LOCAL_ACTION_END_DX2 = 4,
  SEG6_LOCAL_ACTION_END_DX6 = 5,
  SEG6_LOCAL_ACTION_END_DX4 = 6,
  SEG6_LOCAL_ACTION_END_DT6 = 7,
  SEG6_LOCAL_ACTION_END_DT4 = 8,
  SEG6_LOCAL_ACTION_END_B6 = 9,
  SEG6_LOCAL_ACTION_END_B6_ENCAP = 10,
  SEG6_LOCAL_ACTION_END_BM = 11,
  SEG6_LOCAL_ACTION_END_S = 12,
  SEG6_LOCAL_ACTION_END_AS = 13,
  SEG6_LOCAL_ACTION_END_AM = 14,
  SEG6_LOCAL_ACTION_END_BPF = 15,
  __SEG6_LOCAL_ACTION_MAX,
};
#define SEG6_LOCAL_ACTION_MAX (__SEG6_LOCAL_ACTION_MAX - 1)
enum {
  SEG6_LOCAL_BPF_PROG_UNSPEC,
  SEG6_LOCAL_BPF_PROG,
  SEG6_LOCAL_BPF_PROG_NAME,
  __SEG6_LOCAL_BPF_PROG_MAX,
};
#define SEG6_LOCAL_BPF_PROG_MAX (__SEG6_LOCAL_BPF_PROG_MAX - 1)
#endif