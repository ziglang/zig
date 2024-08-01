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
#ifndef _XT_TCPOPTSTRIP_H
#define _XT_TCPOPTSTRIP_H
#include <linux/types.h>
#define tcpoptstrip_set_bit(bmap,idx) (bmap[(idx) >> 5] |= 1U << (idx & 31))
#define tcpoptstrip_test_bit(bmap,idx) (((1U << (idx & 31)) & bmap[(idx) >> 5]) != 0)
struct xt_tcpoptstrip_target_info {
  __u32 strip_bmap[8];
};
#endif