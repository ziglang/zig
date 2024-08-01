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
#ifndef __LINUX_TC_EM_TEXT_H
#define __LINUX_TC_EM_TEXT_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
#define TC_EM_TEXT_ALGOSIZ 16
struct tcf_em_text {
  char algo[TC_EM_TEXT_ALGOSIZ];
  __u16 from_offset;
  __u16 to_offset;
  __u16 pattern_len;
  __u8 from_layer : 4;
  __u8 to_layer : 4;
  __u8 pad;
};
#endif