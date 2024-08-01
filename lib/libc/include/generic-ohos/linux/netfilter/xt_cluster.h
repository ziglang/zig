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
#ifndef _XT_CLUSTER_MATCH_H
#define _XT_CLUSTER_MATCH_H
#include <linux/types.h>
enum xt_cluster_flags {
  XT_CLUSTER_F_INV = (1 << 0)
};
struct xt_cluster_match_info {
  __u32 total_nodes;
  __u32 node_mask;
  __u32 hash_seed;
  __u32 flags;
};
#define XT_CLUSTER_NODES_MAX 32
#endif