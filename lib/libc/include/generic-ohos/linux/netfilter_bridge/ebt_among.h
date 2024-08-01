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
#ifndef __LINUX_BRIDGE_EBT_AMONG_H
#define __LINUX_BRIDGE_EBT_AMONG_H
#include <linux/types.h>
#define EBT_AMONG_DST 0x01
#define EBT_AMONG_SRC 0x02
struct ebt_mac_wormhash_tuple {
  __u32 cmp[2];
  __be32 ip;
};
struct ebt_mac_wormhash {
  int table[257];
  int poolsize;
  struct ebt_mac_wormhash_tuple pool[0];
};
#define ebt_mac_wormhash_size(x) ((x) ? sizeof(struct ebt_mac_wormhash) + (x)->poolsize * sizeof(struct ebt_mac_wormhash_tuple) : 0)
struct ebt_among_info {
  int wh_dst_ofs;
  int wh_src_ofs;
  int bitmask;
};
#define EBT_AMONG_DST_NEG 0x1
#define EBT_AMONG_SRC_NEG 0x2
#define ebt_among_wh_dst(x) ((x)->wh_dst_ofs ? (struct ebt_mac_wormhash *) ((char *) (x) + (x)->wh_dst_ofs) : NULL)
#define ebt_among_wh_src(x) ((x)->wh_src_ofs ? (struct ebt_mac_wormhash *) ((char *) (x) + (x)->wh_src_ofs) : NULL)
#define EBT_AMONG_MATCH "among"
#endif