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
#ifndef _NF_SYNPROXY_H
#define _NF_SYNPROXY_H
#include <linux/types.h>
#define NF_SYNPROXY_OPT_MSS 0x01
#define NF_SYNPROXY_OPT_WSCALE 0x02
#define NF_SYNPROXY_OPT_SACK_PERM 0x04
#define NF_SYNPROXY_OPT_TIMESTAMP 0x08
#define NF_SYNPROXY_OPT_ECN 0x10
#define NF_SYNPROXY_OPT_MASK (NF_SYNPROXY_OPT_MSS | NF_SYNPROXY_OPT_WSCALE | NF_SYNPROXY_OPT_SACK_PERM | NF_SYNPROXY_OPT_TIMESTAMP)
struct nf_synproxy_info {
  __u8 options;
  __u8 wscale;
  __u16 mss;
};
#endif