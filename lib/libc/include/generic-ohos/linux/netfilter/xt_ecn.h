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
#ifndef _XT_ECN_H
#define _XT_ECN_H
#include <linux/types.h>
#include <linux/netfilter/xt_dscp.h>
#define XT_ECN_IP_MASK (~XT_DSCP_MASK)
#define XT_ECN_OP_MATCH_IP 0x01
#define XT_ECN_OP_MATCH_ECE 0x10
#define XT_ECN_OP_MATCH_CWR 0x20
#define XT_ECN_OP_MATCH_MASK 0xce
struct xt_ecn_info {
  __u8 operation;
  __u8 invert;
  __u8 ip_ect;
  union {
    struct {
      __u8 ect;
    } tcp;
  } proto;
};
#endif