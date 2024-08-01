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
#ifndef _XT_NFQ_TARGET_H
#define _XT_NFQ_TARGET_H
#include <linux/types.h>
struct xt_NFQ_info {
  __u16 queuenum;
};
struct xt_NFQ_info_v1 {
  __u16 queuenum;
  __u16 queues_total;
};
struct xt_NFQ_info_v2 {
  __u16 queuenum;
  __u16 queues_total;
  __u16 bypass;
};
struct xt_NFQ_info_v3 {
  __u16 queuenum;
  __u16 queues_total;
  __u16 flags;
#define NFQ_FLAG_BYPASS 0x01
#define NFQ_FLAG_CPU_FANOUT 0x02
#define NFQ_FLAG_MASK 0x03
};
#endif