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
#ifndef _IPT_ECN_TARGET_H
#define _IPT_ECN_TARGET_H
#include <linux/types.h>
#include <linux/netfilter/xt_DSCP.h>
#define IPT_ECN_IP_MASK (~XT_DSCP_MASK)
#define IPT_ECN_OP_SET_IP 0x01
#define IPT_ECN_OP_SET_ECE 0x10
#define IPT_ECN_OP_SET_CWR 0x20
#define IPT_ECN_OP_MASK 0xce
struct ipt_ECN_info {
  __u8 operation;
  __u8 ip_ect;
  union {
    struct {
      __u8 ece : 1, cwr : 1;
    } tcp;
  } proto;
};
#endif