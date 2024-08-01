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
#ifndef __LINUX_TC_PED_H
#define __LINUX_TC_PED_H
#include <linux/types.h>
#include <linux/pkt_cls.h>
enum {
  TCA_PEDIT_UNSPEC,
  TCA_PEDIT_TM,
  TCA_PEDIT_PARMS,
  TCA_PEDIT_PAD,
  TCA_PEDIT_PARMS_EX,
  TCA_PEDIT_KEYS_EX,
  TCA_PEDIT_KEY_EX,
  __TCA_PEDIT_MAX
};
#define TCA_PEDIT_MAX (__TCA_PEDIT_MAX - 1)
enum {
  TCA_PEDIT_KEY_EX_HTYPE = 1,
  TCA_PEDIT_KEY_EX_CMD = 2,
  __TCA_PEDIT_KEY_EX_MAX
};
#define TCA_PEDIT_KEY_EX_MAX (__TCA_PEDIT_KEY_EX_MAX - 1)
enum pedit_header_type {
  TCA_PEDIT_KEY_EX_HDR_TYPE_NETWORK = 0,
  TCA_PEDIT_KEY_EX_HDR_TYPE_ETH = 1,
  TCA_PEDIT_KEY_EX_HDR_TYPE_IP4 = 2,
  TCA_PEDIT_KEY_EX_HDR_TYPE_IP6 = 3,
  TCA_PEDIT_KEY_EX_HDR_TYPE_TCP = 4,
  TCA_PEDIT_KEY_EX_HDR_TYPE_UDP = 5,
  __PEDIT_HDR_TYPE_MAX,
};
#define TCA_PEDIT_HDR_TYPE_MAX (__PEDIT_HDR_TYPE_MAX - 1)
enum pedit_cmd {
  TCA_PEDIT_KEY_EX_CMD_SET = 0,
  TCA_PEDIT_KEY_EX_CMD_ADD = 1,
  __PEDIT_CMD_MAX,
};
#define TCA_PEDIT_CMD_MAX (__PEDIT_CMD_MAX - 1)
struct tc_pedit_key {
  __u32 mask;
  __u32 val;
  __u32 off;
  __u32 at;
  __u32 offmask;
  __u32 shift;
};
struct tc_pedit_sel {
  tc_gen;
  unsigned char nkeys;
  unsigned char flags;
  struct tc_pedit_key keys[0];
};
#define tc_pedit tc_pedit_sel
#endif