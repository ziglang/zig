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
#ifndef _IPT_CLUSTERIP_H_target
#define _IPT_CLUSTERIP_H_target
#include <linux/types.h>
#include <linux/if_ether.h>
enum clusterip_hashmode {
  CLUSTERIP_HASHMODE_SIP = 0,
  CLUSTERIP_HASHMODE_SIP_SPT,
  CLUSTERIP_HASHMODE_SIP_SPT_DPT,
};
#define CLUSTERIP_HASHMODE_MAX CLUSTERIP_HASHMODE_SIP_SPT_DPT
#define CLUSTERIP_MAX_NODES 16
#define CLUSTERIP_FLAG_NEW 0x00000001
struct clusterip_config;
struct ipt_clusterip_tgt_info {
  __u32 flags;
  __u8 clustermac[ETH_ALEN];
  __u16 num_total_nodes;
  __u16 num_local_nodes;
  __u16 local_nodes[CLUSTERIP_MAX_NODES];
  __u32 hash_mode;
  __u32 hash_initval;
  struct clusterip_config * config;
};
#endif