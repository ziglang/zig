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
#ifndef __LINUX_TC_EM_CMP_H
#define __LINUX_TC_EM_CMP_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
struct tcf_em_cmp {
  __u32 val;
  __u32 mask;
  __u16 off;
  __u8 align : 4;
  __u8 flags : 4;
  __u8 layer : 4;
  __u8 opnd : 4;
};
enum {
  TCF_EM_ALIGN_U8 = 1,
  TCF_EM_ALIGN_U16 = 2,
  TCF_EM_ALIGN_U32 = 4
};
#define TCF_EM_CMP_TRANS 1
#endif